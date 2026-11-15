import Foundation

/// Trivia built from fact tables: each fact becomes a question whose wrong options come from the same table.
enum TriviaTables {
    static let capitals: [(String, String)] = [
        ("Francia", "París"), ("Italia", "Roma"), ("Alemania", "Berlín"), ("Portugal", "Lisboa"), ("Reino Unido", "Londres"),
        ("Irlanda", "Dublín"), ("Países Bajos", "Ámsterdam"), ("Bélgica", "Bruselas"), ("Suiza", "Berna"), ("Austria", "Viena"),
        ("Polonia", "Varsovia"), ("Chequia", "Praga"), ("Hungría", "Budapest"), ("Grecia", "Atenas"), ("Suecia", "Estocolmo"),
        ("Noruega", "Oslo"), ("Dinamarca", "Copenhague"), ("Finlandia", "Helsinki"), ("Islandia", "Reikiavik"), ("Rumanía", "Bucarest"),
        ("Bulgaria", "Sofía"), ("Croacia", "Zagreb"), ("Serbia", "Belgrado"), ("Ucrania", "Kiev"), ("Rusia", "Moscú"),
        ("Turquía", "Ankara"), ("Marruecos", "Rabat"), ("Egipto", "El Cairo"), ("Kenia", "Nairobi"), ("Nigeria", "Abuya"),
        ("Etiopía", "Adís Abeba"), ("Sudáfrica", "Pretoria"), ("Senegal", "Dakar"), ("Ghana", "Acra"), ("Argelia", "Argel"),
        ("Túnez", "Túnez"), ("Canadá", "Ottawa"), ("Estados Unidos", "Washington D. C."), ("México", "Ciudad de México"), ("Cuba", "La Habana"),
        ("Guatemala", "Ciudad de Guatemala"), ("Honduras", "Tegucigalpa"), ("Nicaragua", "Managua"), ("Costa Rica", "San José"), ("Panamá", "Ciudad de Panamá"),
        ("Colombia", "Bogotá"), ("Venezuela", "Caracas"), ("Ecuador", "Quito"), ("Perú", "Lima"), ("Bolivia", "Sucre"),
        ("Chile", "Santiago"), ("Argentina", "Buenos Aires"), ("Uruguay", "Montevideo"), ("Paraguay", "Asunción"), ("Brasil", "Brasilia"),
        ("República Dominicana", "Santo Domingo"), ("Japón", "Tokio"), ("China", "Pekín"), ("Corea del Sur", "Seúl"), ("India", "Nueva Delhi"),
        ("Pakistán", "Islamabad"), ("Tailandia", "Bangkok"), ("Vietnam", "Hanói"), ("Filipinas", "Manila"), ("Indonesia", "Yakarta"),
        ("Australia", "Canberra"), ("Nueva Zelanda", "Wellington"), ("Irán", "Teherán"), ("Arabia Saudí", "Riad"), ("Jordania", "Amán"),
        ("Mongolia", "Ulán Bator"), ("Nepal", "Katmandú"), ("Kazajistán", "Astaná"), ("Malasia", "Kuala Lumpur"), ("Bangladés", "Daca"),
    ]

    static let symbols: [(String, String)] = [
        ("Fe", "Hierro"), ("Au", "Oro"), ("Ag", "Plata"), ("Cu", "Cobre"), ("Pb", "Plomo"), ("Na", "Sodio"), ("K", "Potasio"),
        ("Hg", "Mercurio"), ("Sn", "Estaño"), ("Zn", "Cinc"), ("Ca", "Calcio"), ("Mg", "Magnesio"), ("O", "Oxígeno"), ("N", "Nitrógeno"),
        ("C", "Carbono"), ("H", "Hidrógeno"), ("He", "Helio"), ("Cl", "Cloro"), ("S", "Azufre"), ("P", "Fósforo"), ("Si", "Silicio"),
        ("Al", "Aluminio"), ("Ne", "Neón"), ("U", "Uranio"), ("Pt", "Platino"), ("Ni", "Níquel"), ("I", "Yodo"), ("W", "Wolframio"),
        ("Li", "Litio"), ("F", "Flúor"),
    ]

    static let books: [(String, String)] = [
        ("Don Quijote de la Mancha", "Miguel de Cervantes"), ("Cien años de soledad", "Gabriel García Márquez"), ("La casa de los espíritus", "Isabel Allende"),
        ("Rayuela", "Julio Cortázar"), ("Ficciones", "Jorge Luis Borges"), ("La ciudad y los perros", "Mario Vargas Llosa"), ("Pedro Páramo", "Juan Rulfo"),
        ("Bodas de sangre", "Federico García Lorca"), ("La Regenta", "Leopoldo Alas «Clarín»"), ("Fortunata y Jacinta", "Benito Pérez Galdós"),
        ("Campos de Castilla", "Antonio Machado"), ("Platero y yo", "Juan Ramón Jiménez"), ("Luces de bohemia", "Ramón María del Valle-Inclán"),
        ("La colmena", "Camilo José Cela"), ("Nada", "Carmen Laforet"), ("Cinco horas con Mario", "Miguel Delibes"), ("La sombra del viento", "Carlos Ruiz Zafón"),
        ("El capitán Alatriste", "Arturo Pérez-Reverte"), ("Romeo y Julieta", "William Shakespeare"), ("Hamlet", "William Shakespeare"),
        ("Orgullo y prejuicio", "Jane Austen"), ("Cumbres borrascosas", "Emily Brontë"), ("Oliver Twist", "Charles Dickens"),
        ("1984", "George Orwell"), ("Un mundo feliz", "Aldous Huxley"), ("El viejo y el mar", "Ernest Hemingway"), ("Moby Dick", "Herman Melville"),
        ("Las aventuras de Tom Sawyer", "Mark Twain"), ("Frankenstein", "Mary Shelley"), ("Drácula", "Bram Stoker"), ("El retrato de Dorian Gray", "Oscar Wilde"),
        ("Los miserables", "Victor Hugo"), ("El principito", "Antoine de Saint-Exupéry"), ("Madame Bovary", "Gustave Flaubert"),
        ("Veinte mil leguas de viaje submarino", "Julio Verne"), ("Crimen y castigo", "Fiódor Dostoievski"), ("Guerra y paz", "León Tolstói"),
        ("La metamorfosis", "Franz Kafka"), ("El nombre de la rosa", "Umberto Eco"), ("La Divina comedia", "Dante Alighieri"),
        ("El Hobbit", "J. R. R. Tolkien"), ("Harry Potter y la piedra filosofal", "J. K. Rowling"), ("Alicia en el país de las maravillas", "Lewis Carroll"),
        ("La Odisea", "Homero"), ("El perfume", "Patrick Süskind"),
    ]

    static let paintings: [(String, String)] = [
        ("Las meninas", "Diego Velázquez"), ("Guernica", "Pablo Picasso"), ("La Gioconda", "Leonardo da Vinci"), ("La noche estrellada", "Vincent van Gogh"),
        ("El grito", "Edvard Munch"), ("La persistencia de la memoria", "Salvador Dalí"), ("El jardín de las delicias", "El Bosco"),
        ("Los fusilamientos del 3 de mayo", "Francisco de Goya"), ("El nacimiento de Venus", "Sandro Botticelli"), ("La joven de la perla", "Johannes Vermeer"),
        ("La ronda de noche", "Rembrandt"), ("El beso", "Gustav Klimt"), ("Impresión, sol naciente", "Claude Monet"), ("La creación de Adán", "Miguel Ángel"),
        ("El entierro del conde de Orgaz", "El Greco"), ("Los girasoles", "Vincent van Gogh"), ("La libertad guiando al pueblo", "Eugène Delacroix"),
        ("Las señoritas de Avignon", "Pablo Picasso"), ("Saturno devorando a su hijo", "Francisco de Goya"), ("La última cena", "Leonardo da Vinci"),
        ("Las tres gracias", "Pedro Pablo Rubens"), ("El hijo del hombre", "René Magritte"), ("Nighthawks (Halcones de la noche)", "Edward Hopper"),
        ("Las hilanderas", "Diego Velázquez"), ("La maja desnuda", "Francisco de Goya"),
    ]

    static let generated: [QuizItem] = {
        var items: [QuizItem] = []
        func wrong<T>(_ table: [T], excluding index: Int, value: (T) -> String, correct: String, salt: Int) -> [String] {
            var random = SeededRandom(seed: UInt64(index * 7919 + salt))
            var picked: [String] = []
            for candidate in random.shuffled(Array(table.indices)) where candidate != index {
                let option = value(table[candidate])
                if option != correct && !picked.contains(option) { picked.append(option) }
                if picked.count == 3 { break }
            }
            return picked
        }
        for (i, (country, capital)) in capitals.enumerated() {
            items.append(QuizItem(question: "¿Cuál es la capital de \(country)?", answer: capital,
                                  wrong: wrong(capitals, excluding: i, value: { $0.1 }, correct: capital, salt: 1),
                                  explanation: "La capital de \(country) es \(capital)."))
            if country != capital {
                items.append(QuizItem(question: "\(capital) es la capital de…", answer: country,
                                      wrong: wrong(capitals, excluding: i, value: { $0.0 }, correct: country, salt: 2),
                                      explanation: "\(capital) es la capital de \(country)."))
            }
        }
        for (i, (symbol, element)) in symbols.enumerated() {
            items.append(QuizItem(question: "¿Qué elemento químico tiene el símbolo «\(symbol)»?", answer: element,
                                  wrong: wrong(symbols, excluding: i, value: { $0.1 }, correct: element, salt: 3),
                                  explanation: "«\(symbol)» es el símbolo químico de: \(element)."))
        }
        for (i, (book, author)) in books.enumerated() {
            items.append(QuizItem(question: "¿Quién escribió «\(book)»?", answer: author,
                                  wrong: wrong(books, excluding: i, value: { $0.1 }, correct: author, salt: 4),
                                  explanation: "«\(book)» es obra de \(author)."))
        }
        for (i, (painting, painter)) in paintings.enumerated() {
            items.append(QuizItem(question: "¿Quién pintó «\(painting)»?", answer: painter,
                                  wrong: wrong(paintings, excluding: i, value: { $0.1 }, correct: painter, salt: 5),
                                  explanation: "«\(painting)» es de \(painter)."))
        }
        return items
    }()
}
