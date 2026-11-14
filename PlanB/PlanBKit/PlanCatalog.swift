/// Every built-in plan. Ids are slugs of the titles, so they stay stable across versions.
public enum PlanCatalog {
    public static let all: [Plan] = calm + romantic + active + adventure + creative + intimate

    public static let byID: [String: Plan] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    public static func plan(id: String) -> Plan? { byID[id] }
}
