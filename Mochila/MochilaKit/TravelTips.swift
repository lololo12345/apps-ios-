import Foundation

/// Short packing tips: one a day in the widget and on the empty screen.
enum TravelTips {
    static let all: [String] = [
        "Enrolla la ropa en vez de doblarla: ocupa menos y se arruga menos.",
        "Lleva una muda en el equipaje de mano por si se pierde la maleta.",
        "Haz una foto a tu DNI y a las reservas por si las pierdes.",
        "Mete los zapatos en una bolsa para no manchar la ropa.",
        "Usa los calcetines para rellenar los zapatos y ganar espacio.",
        "Los líquidos del equipaje de mano, en botes de 100 ml y bolsa transparente.",
        "Descarga mapas sin conexión antes de salir.",
        "Lleva una batería externa cargada: el móvil es tu billete, mapa y cámara.",
        "Un pañuelo grande sirve de bufanda, toalla o manta en el avión.",
        "Deja una copia de las llaves a alguien de confianza si te vas muchos días.",
        "Vacía la nevera de lo que caduca antes de irte.",
        "Haz el check-in online y te ahorras la cola del mostrador.",
        "Lleva una bolsa para la ropa sucia y la separas de la limpia.",
        "Pesa la maleta en casa para no pagar sobrepeso en el aeropuerto.",
        "Guarda los cargadores en una bolsita para no dejarte ninguno.",
        "Revisa la cama y los enchufes del hotel antes de irte.",
        "La crema solar también hace falta en la nieve y en la montaña.",
        "Pon una cinta de color en tu maleta para reconocerla en la cinta.",
        "Lleva tus medicinas en el equipaje de mano, nunca facturadas.",
        "Una botella reutilizable te ahorra dinero y plástico.",
    ]

    /// Same tip all day, a new one tomorrow.
    static func tip(for date: Date = .now, calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}
