/// A FetchRequest built from raw SQL.
public struct SQLRequest<RowDecoder>: FetchRequest {
    /// There are two statement caches: one "public" for statements generated by
    /// the user, and one "internal" for the statements generated by GRDB. Those
    /// are separated so that GRDB has no opportunity to inadvertently modify
    /// the arguments of user's cached statements.
    enum Cache {
        /// The public cache, for library user
        case `public`
        
        /// The internal cache, for GRDB
        case `internal`
    }
    
    /// The request adapter
    public var adapter: RowAdapter?
    
    private(set) var sqlLiteral: SQLLiteral
    private let cache: Cache?
    
    /// Creates a request from an SQL string, optional arguments, and
    /// optional row adapter.
    ///
    ///     let request = SQLRequest<String>(sql: """
    ///         SELECT name FROM player
    ///         """)
    ///     let request = SQLRequest<Player>(sql: """
    ///         SELECT * FROM player WHERE id = ?
    ///         """, arguments: [1])
    ///
    /// - parameters:
    ///     - sql: An SQL query.
    ///     - arguments: Statement arguments.
    ///     - adapter: Optional RowAdapter.
    ///     - cached: Defaults to false. If true, the request reuses a cached
    ///       prepared statement.
    /// - returns: A SQLRequest
    public init(
        sql: String,
        arguments: StatementArguments = StatementArguments(),
        adapter: RowAdapter? = nil,
        cached: Bool = false)
    {
        self.init(
            literal: SQLLiteral(sql: sql, arguments: arguments),
            adapter: adapter,
            fromCache: cached ? .public : nil)
    }
    
    /// Creates a request from an SQLLiteral, and optional row adapter.
    ///
    ///     let request = SQLRequest<String>(literal: SQLLiteral(sql: """
    ///         SELECT name FROM player
    ///         """))
    ///     let request = SQLRequest<Player>(literal: SQLLiteral(sql: """
    ///         SELECT * FROM player WHERE name = ?
    ///         """, arguments: ["O'Brien"]))
    ///
    /// With Swift 5, you can safely embed raw values in your SQL queries,
    /// without any risk of syntax errors or SQL injection:
    ///
    ///     let request = SQLRequest<Player>(literal: """
    ///         SELECT * FROM player WHERE name = \("O'brien")
    ///         """)
    ///
    /// - parameters:
    ///     - sqlLiteral: An SQLLiteral.
    ///     - adapter: Optional RowAdapter.
    ///     - cached: Defaults to false. If true, the request reuses a cached
    ///       prepared statement.
    /// - returns: A SQLRequest
    public init(literal sqlLiteral: SQLLiteral, adapter: RowAdapter? = nil, cached: Bool = false) {
        self.init(literal: sqlLiteral, adapter: adapter, fromCache: cached ? .public : nil)
    }
    
    /// Creates a request from an SQLLiteral, and optional row adapter.
    ///
    ///     let request = SQLRequest<String>(literal: SQLLiteral(sql: """
    ///         SELECT name FROM player
    ///         """))
    ///     let request = SQLRequest<Player>(literal: SQLLiteral(sql: """
    ///         SELECT * FROM player WHERE name = ?
    ///         """, arguments: ["O'Brien"]))
    ///
    /// With Swift 5, you can safely embed raw values in your SQL queries,
    /// without any risk of syntax errors or SQL injection:
    ///
    ///     let request = SQLRequest<Player>(literal: """
    ///         SELECT * FROM player WHERE name = \("O'brien")
    ///         """)
    ///
    /// - parameters:
    ///     - sqlLiteral: An SQLLiteral.
    ///     - adapter: Optional RowAdapter.
    ///     - cache: The eventual cache
    /// - returns: A SQLRequest
    init(literal sqlLiteral: SQLLiteral, adapter: RowAdapter? = nil, fromCache cache: Cache?) {
        self.sqlLiteral = sqlLiteral
        self.adapter = adapter
        self.cache = cache
    }
    
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    ///
    /// - parameter db: A database connection.
    /// - parameter singleResult: SQLRequest disregards this hint.
    ///
    /// :nodoc:
    public func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest {
        var context = SQLGenerationContext.sqlLiteralContext(db)
        let sql = try sqlLiteral.sql(&context)
        let statement: SelectStatement
        switch cache {
        case .none:
            statement = try db.makeSelectStatement(sql: sql)
        case .public?:
            statement = try db.cachedSelectStatement(sql: sql)
        case .internal?:
            statement = try db.internalCachedSelectStatement(sql: sql)
        }
        try statement.setArguments(context.arguments)
        return PreparedRequest(statement: statement, adapter: adapter)
    }
}

extension SQLRequest: SQLCollection {
    /// :nodoc
    public func collectionSQL(_ context: inout SQLGenerationContext) throws -> String {
        try sqlLiteral.sql(&context)
    }
}

extension SQLRequest: SQLExpression {
    /// :nodoc
    public func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        try "(" + sqlLiteral.sql(&context) + ")"
    }
    
    /// :nodoc
    public func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return self
    }
}

extension SQLRequest: ExpressibleByStringInterpolation {
    /// :nodoc
    public init(unicodeScalarLiteral: String) {
        self.init(sql: unicodeScalarLiteral)
    }
    
    /// :nodoc:
    public init(extendedGraphemeClusterLiteral: String) {
        self.init(sql: extendedGraphemeClusterLiteral)
    }
    
    /// :nodoc:
    public init(stringLiteral: String) {
        self.init(sql: stringLiteral)
    }
    
    /// :nodoc:
    public init(stringInterpolation sqlInterpolation: SQLInterpolation) {
        self.init(literal: SQLLiteral(stringInterpolation: sqlInterpolation))
    }
}
