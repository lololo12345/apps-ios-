#!/usr/bin/env python3
"""Create a complete, polished Android app (Kotlin + Jetpack Compose) that builds, passes its tests and
takes screenshots from minute one. Same conventions as RondaAndroid.

    python3 tools/new_android_app.py <Name> <application.id> --display "Nombre" --summary "Qué es"
        [--accent FFB020] [--background 120C2E] [--glyph N] [--root .] [--no-register]

Creates <Name>Android/ with:
  Gradle wrapper + version catalog (tools/android/, the versions RondaAndroid ships with)
  app/sideload.keystore    fixed signing key so every APK installs over the previous one
  core/                    plain-Kotlin logic (unit-tested on the JVM)
  data/                    KeyValueStore (in-memory for tests, SharedPreferences in the app) + AppState
  ui/theme                 colours, background glow, glass cards, buttons, haptics
  ui/                      App with bottom navigation, Home and Settings screens
  test/                    JUnit logic tests + Robolectric/Roborazzi UI flow with screenshots
  README.md                template

CI needs no edit: .github/workflows/android.yml finds every <Dir>Android with a gradlew by itself.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
from make_icon import make_icon  # noqa: E402

DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def write(path: str, text: str, overwrite: bool = False) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path) and not overwrite:
        return
    with open(path, "w") as f:
        f.write(text)


def darken(hex_text: str, factor: float) -> str:
    value = int(hex_text.lstrip("#"), 16)
    return "".join(f"{int(((value >> s) & 0xFF) * factor):02X}" for s in (16, 8, 0))


def lighten(hex_text: str, amount: float) -> str:
    value = int(hex_text.lstrip("#"), 16)
    return "".join(f"{int(((value >> s) & 0xFF) + (255 - ((value >> s) & 0xFF)) * amount):02X}" for s in (16, 8, 0))


SETTINGS_GRADLE = """pluginManagement {{
    repositories {{
        google()
        mavenCentral()
        gradlePluginPortal()
    }}
}}
dependencyResolutionManagement {{
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {{
        google()
        mavenCentral()
    }}
}}
rootProject.name = "{name}"
include(":app")
"""

ROOT_GRADLE = """plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.roborazzi) apply false
}
"""

GRADLE_PROPERTIES = """org.gradle.jvmargs=-Xmx4g -Dfile.encoding=UTF-8
org.gradle.caching=true
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
"""

GITIGNORE = """.gradle/
build/
app/build/
local.properties
*.iml
.idea/
.kotlin/
"""

APP_GRADLE = """plugins {{
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.roborazzi)
}}

android {{
    namespace = "{package}"
    compileSdk = 36

    defaultConfig {{
        applicationId = "{package}"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }}

    signingConfigs {{
        // Sideload key committed on purpose (same idea as Android's public debug key) so every APK built
        // here or in CI installs over the previous one. Google Play needs a private key instead.
        create("sideload") {{
            storeFile = file("sideload.keystore")
            storePassword = "android"
            keyAlias = "{alias}"
            keyPassword = "android"
        }}
    }}

    buildTypes {{
        debug {{
            signingConfig = signingConfigs.getByName("sideload")
        }}
        release {{
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("sideload")
        }}
    }}

    compileOptions {{
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }}

    buildFeatures {{
        compose = true
    }}

    testOptions {{
        unitTests {{
            isIncludeAndroidResources = true
            all {{
                it.systemProperty("robolectric.pixelCopyRenderMode", "hardware")
                it.systemProperty("roborazzi.test.record", "true")
            }}
        }}
    }}
}}

kotlin {{
    compilerOptions {{
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }}
}}

dependencies {{
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.foundation)
    implementation(libs.compose.animation)
    implementation(libs.compose.material3)
    implementation(libs.compose.icons.extended)
    implementation(libs.kotlinx.serialization.json)

    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.junit)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
    debugImplementation(libs.compose.ui.test.manifest)
}}
"""

PROGUARD = """# kotlinx.serialization keeps generated serializers through its own consumer rules.
-keepattributes *Annotation*, InnerClasses
"""

MANIFEST = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.VIBRATE" />
    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher"
        android:label="{display}"
        android:supportsRtl="true"
        android:theme="@style/Theme.{name}">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:screenOrientation="portrait"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
"""

THEMES = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="background">#FF{background}</color>
    <style name="Theme.{name}" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">@color/background</item>
        <item name="android:statusBarColor">@android:color/transparent</item>
        <item name="android:navigationBarColor">@android:color/transparent</item>
    </style>
</resources>
"""

MAIN_ACTIVITY = """package {package}

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Display
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import {package}.data.AppState
import {package}.data.SharedPreferencesStore
import {package}.ui.{name}App
import {package}.ui.theme.Haptics

class MainActivity : ComponentActivity() {{
    private val state by lazy {{ AppState(SharedPreferencesStore(getSharedPreferences("{alias}", MODE_PRIVATE))) }}

    override fun onCreate(savedInstanceState: Bundle?) {{
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
        )
        requestHighestRefreshRate()
        Haptics.install(this)
        Haptics.enabled = {{ state.hapticsOn }}
        val reduceMotion = runCatching {{
            Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
        }}.getOrDefault(false)
        setContent {{ {name}App(state, reduceMotion) }}
    }}

    /** Fastest refresh rate the screen offers at its current resolution (90/120 Hz where available). */
    private fun requestHighestRefreshRate() {{
        val display: Display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else null)
            ?: @Suppress("DEPRECATION") windowManager.defaultDisplay
            ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter {{ it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }}
            .maxByOrNull {{ it.refreshRate }} ?: return
        window.attributes = window.attributes.also {{
            it.preferredDisplayModeId = best.modeId
            it.preferredRefreshRate = best.refreshRate
        }}
    }}
}}
"""

CORE = """package {package}.core

import java.text.NumberFormat
import java.util.Locale

/** Plain-Kotlin helpers (no Android): unit-tested on the JVM. */
object Format {{
    private val spanish = Locale.forLanguageTag("es-ES")

    /** 12.345 with Spanish grouping. */
    fun grouped(value: Int): String = NumberFormat.getIntegerInstance(spanish).format(value)

    /** "domingo, 15 de noviembre" → "Domingo, 15 de noviembre" (only the first letter). */
    fun sentenceCased(text: String): String = text.replaceFirstChar {{ it.titlecase(spanish) }}
}}
"""

DATA = """package {package}.data

import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** Tiny persistence abstraction so state can be unit-tested without Android. */
interface KeyValueStore {{
    fun getInt(key: String): Int?
    fun putInt(key: String, value: Int)
    fun getBoolean(key: String, default: Boolean): Boolean
    fun putBoolean(key: String, value: Boolean)
}}

class InMemoryStore : KeyValueStore {{
    private val values = mutableMapOf<String, Any>()
    override fun getInt(key: String) = values[key] as? Int
    override fun putInt(key: String, value: Int) {{ values[key] = value }}
    override fun getBoolean(key: String, default: Boolean) = values[key] as? Boolean ?: default
    override fun putBoolean(key: String, value: Boolean) {{ values[key] = value }}
}}

class SharedPreferencesStore(private val prefs: SharedPreferences) : KeyValueStore {{
    override fun getInt(key: String): Int? = if (prefs.contains(key)) prefs.getInt(key, 0) else null
    override fun putInt(key: String, value: Int) {{ prefs.edit().putInt(key, value).apply() }}
    override fun getBoolean(key: String, default: Boolean) = prefs.getBoolean(key, default)
    override fun putBoolean(key: String, value: Boolean) {{ prefs.edit().putBoolean(key, value).apply() }}
}}

/** App-wide state observed by Compose; every change is saved immediately. */
class AppState(private val store: KeyValueStore) {{
    var hapticsOn by mutableStateOf(store.getBoolean(KEY_HAPTICS, true))
        private set
    var taps by mutableStateOf(store.getInt(KEY_TAPS) ?: 0)
        private set

    fun setHaptics(on: Boolean) {{
        hapticsOn = on
        store.putBoolean(KEY_HAPTICS, on)
    }}

    fun tap() {{
        taps += 1
        store.putInt(KEY_TAPS, taps)
    }}

    fun reset() {{
        setHaptics(true)
        taps = 0
        store.putInt(KEY_TAPS, 0)
    }}

    private companion object {{
        const val KEY_HAPTICS = "settings.haptics"
        const val KEY_TAPS = "home.taps"
    }}
}}
"""

THEME = """package {package}.ui.theme

import android.app.Activity
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.max

/** Brand colours and sizes (dark design: the same look in every lighting). */
object Brand {{
    val accent = Color(0xFF{accent})
    val accentSoft = Color(0xFF{accent_soft})
    val background = Color(0xFF{background})
    val backgroundDeep = Color(0xFF{background_deep})
    val good = Color(0xFF3DDC97)
    val bad = Color(0xFFFF5A6E)
    val secondaryText = Color.White.copy(alpha = 0.64f)

    /** Translucent "glass" fill and rim (Android has no Liquid Glass; this mimics its look). */
    val glassFill = Color.White.copy(alpha = 0.08f)
    val glassRim = Color.White.copy(alpha = 0.15f)

    val gutter = 16.dp
    val radius = 24.dp
}}

/** Respects the system "remove animations" setting (set from MainActivity). */
val LocalReduceMotion = compositionLocalOf {{ false }}

@Composable
fun BrandTheme(content: @Composable () -> Unit) {{
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Brand.accent,
            onPrimary = Brand.backgroundDeep,
            background = Brand.background,
            surface = Brand.background,
            onBackground = Color.White,
            onSurface = Color.White,
        ),
    ) {{
        // Text outside a Surface takes LocalContentColor: make it white so nothing renders black on the dark background.
        CompositionLocalProvider(LocalContentColor provides Color.White, content = content)
    }}
}}

/** Vertical gradient plus two soft radial glows; drawn once, cheap at 120 Hz. */
fun Modifier.brandBackground(glow: Color = Brand.accent): Modifier = drawBehind {{
    val longest = max(size.width, size.height)
    drawRect(Brush.verticalGradient(listOf(Brand.background, Brand.backgroundDeep)))
    drawRect(Brush.radialGradient(listOf(glow.copy(alpha = 0.30f), Color.Transparent),
        center = Offset(size.width * 0.95f, 0f), radius = longest * 0.55f))
    drawRect(Brush.radialGradient(listOf(Brand.accentSoft.copy(alpha = 0.16f), Color.Transparent),
        center = Offset(0f, size.height * 0.75f), radius = longest * 0.6f))
}}

/** Rounded glass card with a soft press-down when it is tappable. */
@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    tint: Color? = null,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {{
    val interaction = remember {{ MutableInteractionSource() }}
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, spring(stiffness = 600f), label = "press")
    val shape = RoundedCornerShape(Brand.radius)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .graphicsLayer {{ scaleX = scale; scaleY = scale }}
            .background(tint?.copy(alpha = 0.18f) ?: Brand.glassFill, shape)
            .border(1.dp, Brand.glassRim, shape)
            .then(if (onClick != null) Modifier.clickable(interaction, indication = null) {{ Haptics.tap(); onClick() }} else Modifier)
            .padding(16.dp),
        content = content,
    )
}}

/** Big full-width call to action. */
@Composable
fun PrimaryButton(text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {{
    val interaction = remember {{ MutableInteractionSource() }}
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.96f else 1f, spring(stiffness = 700f), label = "press")
    Box(
        modifier = modifier
            .fillMaxWidth()
            .graphicsLayer {{ scaleX = scale; scaleY = scale }}
            .background(Brush.horizontalGradient(listOf(Brand.accentSoft, Brand.accent)), RoundedCornerShape(50))
            .clickable(interaction, indication = null) {{ Haptics.tap(); onClick() }}
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {{
        Text(text, color = Brand.backgroundDeep, fontWeight = FontWeight.Bold, fontSize = 17.sp)
    }}
}}

/** Full-screen container with the brand background. */
@Composable
fun Screen(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {{
    Box(modifier.fillMaxSize().brandBackground(), content = content)
}}

/** Light haptic ticks, switchable from Settings. */
object Haptics {{
    private var view: View? = null
    var enabled: () -> Boolean = {{ true }}

    fun install(activity: Activity) {{
        view = activity.window.decorView
    }}

    fun tap() {{
        if (enabled()) view?.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
    }}
}}
"""

APP_UI = """package {package}.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import {package}.data.AppState
import {package}.ui.theme.Brand
import {package}.ui.theme.BrandTheme
import {package}.ui.theme.Haptics
import {package}.ui.theme.LocalReduceMotion
import {package}.ui.theme.brandBackground

enum class Tab(val label: String) {{ HOME("Inicio"), SETTINGS("Ajustes") }}

@Composable
fun {name}App(state: AppState, reduceMotion: Boolean = false) {{
    var tab by rememberSaveable {{ mutableStateOf(Tab.HOME) }}
    BrandTheme {{
        CompositionLocalProvider(LocalReduceMotion provides reduceMotion) {{
            Scaffold(
                modifier = Modifier.fillMaxSize().brandBackground(),
                containerColor = Color.Transparent,
                contentColor = Color.White,
                bottomBar = {{
                    NavigationBar(containerColor = Brand.backgroundDeep.copy(alpha = 0.92f)) {{
                        Tab.entries.forEach {{ item ->
                            NavigationBarItem(
                                selected = tab == item,
                                onClick = {{ Haptics.tap(); tab = item }},
                                icon = {{ Icon(if (item == Tab.HOME) Icons.Rounded.Home else Icons.Rounded.Settings, contentDescription = null) }},
                                label = {{ Text(item.label) }},
                                modifier = Modifier.testTag("tab.${{item.name.lowercase()}}"),
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = Brand.backgroundDeep,
                                    selectedTextColor = Brand.accent,
                                    indicatorColor = Brand.accent,
                                    unselectedIconColor = Brand.secondaryText,
                                    unselectedTextColor = Brand.secondaryText,
                                ),
                            )
                        }}
                    }}
                }},
            ) {{ padding ->
                Box(Modifier.padding(padding)) {{
                    AnimatedContent(targetState = tab, transitionSpec = {{ fadeIn() togetherWith fadeOut() }}, label = "tab") {{ current ->
                        when (current) {{
                            Tab.HOME -> HomeScreen(state)
                            Tab.SETTINGS -> SettingsScreen(state)
                        }}
                    }}
                }}
            }}
        }}
    }}
}}
"""

HOME = """package {package}.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import {package}.core.Format
import {package}.data.AppState
import {package}.ui.theme.Brand
import {package}.ui.theme.GlassCard
import {package}.ui.theme.PrimaryButton

@Composable
fun HomeScreen(state: AppState) {{
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .statusBarsPadding()
            .padding(horizontal = Brand.gutter, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {{
        Text(
            "{display}",
            style = TextStyle(brush = Brush.horizontalGradient(listOf(Brand.accentSoft, Brand.accent))),
            fontSize = 36.sp,
            fontWeight = FontWeight.Black,
        )
        Text("{summary}", color = Brand.secondaryText, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
        GlassCard {{
            Text("Empieza aquí", fontWeight = FontWeight.Bold, fontSize = 17.sp)
            Text("Sustituye esta pantalla por la primera de la app.", color = Brand.secondaryText, fontSize = 14.sp)
            Spacer(Modifier.height(12.dp))
            Row {{
                Text("Pulsaciones: ", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                AnimatedContent(
                    targetState = state.taps,
                    transitionSpec = {{ (slideInVertically(tween(220)) {{ it }} + fadeIn()) togetherWith (slideOutVertically(tween(220)) {{ -it }} + fadeOut()) }},
                    label = "taps",
                ) {{ value ->
                    Text(Format.grouped(value), fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.testTag("home.count"))
                }}
            }}
            Spacer(Modifier.height(12.dp))
            PrimaryButton("Pulsar", Modifier.testTag("home.tap")) {{ state.tap() }}
        }}
    }}
}}
"""

SETTINGS = """package {package}.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import {package}.data.AppState
import {package}.ui.theme.Brand
import {package}.ui.theme.GlassCard

@Composable
fun SettingsScreen(state: AppState) {{
    var confirmReset by remember {{ mutableStateOf(false) }}
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .statusBarsPadding()
            .padding(horizontal = Brand.gutter, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {{
        Text("Ajustes", fontSize = 34.sp, fontWeight = FontWeight.Black)
        GlassCard {{
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {{
                Text("Vibración", fontSize = 17.sp, modifier = Modifier.weight(1f))
                Switch(
                    checked = state.hapticsOn,
                    onCheckedChange = {{ state.setHaptics(it) }},
                    modifier = Modifier.testTag("settings.haptics"),
                    colors = SwitchDefaults.colors(checkedTrackColor = Brand.accent, checkedThumbColor = Brand.backgroundDeep),
                )
            }}
        }}
        GlassCard(onClick = {{ confirmReset = true }}, modifier = Modifier.testTag("settings.reset")) {{
            Text("Restablecer ajustes", color = Brand.bad, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
        }}
        Text("{display} · versión 1.0. Todo se guarda solo en este móvil.", color = Brand.secondaryText, fontSize = 13.sp)
    }}
    if (confirmReset) {{
        AlertDialog(
            onDismissRequest = {{ confirmReset = false }},
            title = {{ Text("¿Restablecer los ajustes?") }},
            confirmButton = {{ TextButton(onClick = {{ state.reset(); confirmReset = false }}) {{ Text("Restablecer", color = Brand.bad) }} }},
            dismissButton = {{ TextButton(onClick = {{ confirmReset = false }}) {{ Text("Cancelar") }} }},
        )
    }}
}}
"""

LOGIC_TEST = """package {package}

import {package}.core.Format
import {package}.data.AppState
import {package}.data.InMemoryStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LogicTest {{
    @Test fun formatting() {{
        assertEquals("12.345", Format.grouped(12345))
        assertEquals("Domingo, 15 de noviembre", Format.sentenceCased("domingo, 15 de noviembre"))
    }}

    @Test fun stateIsSavedAndRestored() {{
        val store = InMemoryStore()
        val state = AppState(store)
        assertTrue(state.hapticsOn)
        state.tap(); state.tap()
        state.setHaptics(false)
        val reopened = AppState(store)
        assertEquals(2, reopened.taps)
        assertFalse(reopened.hapticsOn)
        reopened.reset()
        assertEquals(0, AppState(store).taps)
    }}
}}
"""

UI_TEST = """package {package}

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import {package}.data.AppState
import {package}.data.InMemoryStore
import {package}.ui.{name}App
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Flows through the real UI, saving screenshots to app/build/screenshots (exported by CI). */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class UiFlowTest {{
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()

    private fun shot(name: String) {{
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("build/screenshots/$name.png")
    }}

    private fun tap(tag: String) {{
        rule.onNodeWithTag(tag, useUnmergedTree = true).performClick()
        rule.mainClock.advanceTimeBy(600)
        rule.waitForIdle()
    }}

    @Test fun homeAndSettings() {{
        rule.setContent {{ {name}App(AppState(InMemoryStore())) }}
        shot("01-home")
        tap("home.tap")
        rule.onNodeWithTag("home.count", useUnmergedTree = true).assertTextEquals("1")
        tap("tab.settings")
        shot("02-settings")
    }}
}}
"""

README = """# {display} (Android)

{summary}

| Inicio | Ajustes |
|---|---|
| ![](docs/screenshots/01-home.png) | ![](docs/screenshots/02-settings.png) |

## Qué incluye
- (Funciones, en una línea cada una.)

## Proyecto
- Kotlin + Jetpack Compose, `minSdk 26`, 120 Hz donde el móvil lo permite.
- `core/`: lógica pura con tests en la JVM. `data/`: estado y guardado. `ui/`: pantallas y tema.
- Tests: lógica con JUnit y recorridos por la interfaz con Robolectric + Roborazzi (capturas en `app/build/screenshots`).
- `./gradlew testDebugUnitTest` y `./gradlew assembleRelease` (APK firmado con `app/sideload.keystore`).

Todo se guarda solo en el móvil.
"""


def keystore(path: str, alias: str, display: str) -> None:
    if os.path.exists(path):
        return
    keytool = shutil.which("keytool") or os.path.join(os.environ.get("JAVA_HOME", ""), "bin", "keytool")
    subprocess.run([keytool, "-genkeypair", "-keystore", path, "-storepass", "android", "-keypass", "android",
                    "-alias", alias, "-keyalg", "RSA", "-keysize", "2048", "-validity", "36500",
                    "-dname", f"CN={display}, O=Sideload, C=ES", "-noprompt"],
                   check=True, capture_output=True)


def icons(res: str, top: str, bottom: str, glyph: str, color: str) -> None:
    big = os.path.join(res, "mipmap-xxxhdpi", "ic_launcher.png")
    os.makedirs(os.path.dirname(big), exist_ok=True)
    make_icon(big, top, bottom, glyph, color)
    try:
        from PIL import Image
    except ImportError:
        return  # one large icon is enough for Android to scale
    with Image.open(big) as source:
        source.load()
        for density, size in DENSITIES.items():
            out = os.path.join(res, f"mipmap-{density}", "ic_launcher.png")
            os.makedirs(os.path.dirname(out), exist_ok=True)
            source.resize((size, size), Image.LANCZOS).save(out)


def scaffold(args) -> str:
    root = os.path.abspath(args.root)
    name = args.name
    if not re.fullmatch(r"[A-Z][A-Za-z0-9]+", name):
        raise SystemExit("El nombre debe ser CamelCase sin espacios (p. ej. Chispa).")
    if not re.fullmatch(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+", args.application_id):
        raise SystemExit("El application id debe ser como app.chispa.daily (minúsculas y puntos).")
    folder = os.path.join(root, f"{name}Android")
    if os.path.exists(os.path.join(folder, "gradlew")) and not args.force:
        raise SystemExit(f"{name}Android/ ya existe. Usa --force para crear solo lo que falte.")
    package = args.application_id
    fmt = dict(name=name, package=package, alias=re.sub(r"[^a-z0-9]", "", name.lower()),
               display=(args.display or name).replace('"', '\\"'), summary=(args.summary or "Una app nueva.").replace('"', '\\"'),
               accent=args.accent.upper(), accent_soft=lighten(args.accent, 0.35),
               background=args.background.upper(), background_deep=darken(args.background, 0.55))

    template = os.path.join(TOOLS, "android")
    for rel in ("gradlew", "gradlew.bat", "gradle/libs.versions.toml", "gradle/wrapper/gradle-wrapper.jar",
                "gradle/wrapper/gradle-wrapper.properties"):
        dst = os.path.join(folder, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst):
            shutil.copy2(os.path.join(template, rel), dst)
    os.chmod(os.path.join(folder, "gradlew"), 0o755)

    write(os.path.join(folder, "settings.gradle.kts"), SETTINGS_GRADLE.format(**fmt))
    write(os.path.join(folder, "build.gradle.kts"), ROOT_GRADLE)
    write(os.path.join(folder, "gradle.properties"), GRADLE_PROPERTIES)
    write(os.path.join(folder, ".gitignore"), GITIGNORE)
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or ("/root/android-sdk" if os.path.isdir("/root/android-sdk") else "")
    if sdk:
        write(os.path.join(folder, "local.properties"), f"sdk.dir={sdk}\n")

    app = os.path.join(folder, "app")
    write(os.path.join(app, "build.gradle.kts"), APP_GRADLE.format(**fmt))
    write(os.path.join(app, "proguard-rules.pro"), PROGUARD)
    keystore(os.path.join(app, "sideload.keystore"), fmt["alias"], fmt["display"])
    main = os.path.join(app, "src", "main")
    write(os.path.join(main, "AndroidManifest.xml"), MANIFEST.format(**fmt))
    write(os.path.join(main, "res", "values", "themes.xml"), THEMES.format(**fmt))
    icons(os.path.join(main, "res"), lighten(args.background, 0.12), darken(args.background, 0.6), args.glyph or name[0], args.accent)

    src = os.path.join(main, "java", *package.split("."))
    write(os.path.join(src, "MainActivity.kt"), MAIN_ACTIVITY.format(**fmt))
    write(os.path.join(src, "core", "Format.kt"), CORE.format(**fmt))
    write(os.path.join(src, "data", "AppState.kt"), DATA.format(**fmt))
    write(os.path.join(src, "ui", "theme", "Theme.kt"), THEME.format(**fmt))
    write(os.path.join(src, "ui", f"{name}App.kt"), APP_UI.format(**fmt))
    write(os.path.join(src, "ui", "HomeScreen.kt"), HOME.format(**fmt))
    write(os.path.join(src, "ui", "SettingsScreen.kt"), SETTINGS.format(**fmt))
    tests = os.path.join(app, "src", "test", "java", *package.split("."))
    write(os.path.join(tests, "LogicTest.kt"), LOGIC_TEST.format(**fmt))
    write(os.path.join(tests, "UiFlowTest.kt"), UI_TEST.format(**fmt))
    write(os.path.join(folder, "README.md"), README.format(**fmt))
    write(os.path.join(folder, "docs", "screenshots", ".gitkeep"), "")

    index = os.path.join(root, "README.md")
    if args.register and os.path.exists(index):
        text = open(index).read()
        if f"[`{name}Android/`]" not in text:
            lines = text.split("\n")
            last = max(i for i, line in enumerate(lines) if line.startswith("| **"))
            lines.insert(last + 1, f"| **{args.display or name} (Android)** | {args.summary or ''} | [`{name}Android/`]({name}Android/README.md) |")
            open(index, "w").write("\n".join(lines))
    return folder


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("name", help="CamelCase; la carpeta será <Name>Android")
    parser.add_argument("application_id", help="p. ej. app.chispa.daily")
    parser.add_argument("--display")
    parser.add_argument("--summary")
    parser.add_argument("--accent", default="FFB020")
    parser.add_argument("--background", default="120C2E")
    parser.add_argument("--glyph")
    parser.add_argument("--root", default=os.path.dirname(TOOLS))
    parser.add_argument("--no-register", dest="register", action="store_false")
    parser.add_argument("--force", action="store_true")
    path = scaffold(parser.parse_args())
    print(f"Lista: {path}\nPrueba: cd {os.path.basename(path)} && ./gradlew testDebugUnitTest assembleRelease")
