package app.ronda.party.ui.games

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.ContentTransform
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith

/** Card dealt from a deck: the new card scales up from behind, the old one is flicked away. */
fun <T> AnimatedContentTransitionScope<T>.deal(reduceMotion: Boolean): ContentTransform {
    if (reduceMotion) return fadeIn(tween(200)) togetherWith fadeOut(tween(200))
    return (scaleIn(spring(dampingRatio = 0.8f, stiffness = 380f), initialScale = 0.86f) + fadeIn(tween(220))) togetherWith
        (slideOutHorizontally(tween(300)) { -it * 11 / 10 } + fadeOut(tween(300)) + scaleOut(tween(300), targetScale = 0.96f))
}

/** Plain cross-fade. */
fun <T> AnimatedContentTransitionScope<T>.crossFade(): ContentTransform = fadeIn(tween(250)) togetherWith fadeOut(tween(200))
