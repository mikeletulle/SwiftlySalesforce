//
//  Salesforce.swift
//  SwiftlySalesforce
//
//  For license & details see: https://www.github.com/mike4aday/SwiftlySalesforce
//  Copyright (c) 2017. All rights reserved.
//

/// A 'wrapper' around the Salesforce REST API

import Foundation
import PromiseKit

open class Salesforce {

	/// Default Salesforce API version
	static public let defaultVersion = "40.0" // Summer '17
	
	/// Related Connected App
	public private(set) var connectedApp: ConnectedApp
	
	/// API version used for requests
	public var version: String
	
	// JSON decoder
	public var decoder: JSONDecoder
	
	private let q = DispatchQueue.global(qos: .userInitiated)
	private let requestor: Requestor
	
	/// Initializer
	public init(connectedApp: ConnectedApp, version: String = Salesforce.defaultVersion) {
		
		self.connectedApp = connectedApp
		self.version = version
		self.requestor = Requestor.data
		
		self.decoder = JSONDecoder(dateFormatter: DateFormatter.salesforceDateTimeFormatter)
	}
	
	/// Asynchronously requests information about the current user
	/// See https://help.salesforce.com/articleView?id=remoteaccess_using_openid.htm&type=0
	open func identity() -> Promise<Identity> {
		let handler: Requestor.ResponseHandler = {
			(data, response, error) throws -> Data in
			guard let resp = response as? HTTPURLResponse, resp.statusCode != 403 else {
				throw RequestError.userAuthenticationRequired
			}
			return try Requestor.defaultResponseHandler(data, response, error)
		}
		let resource = Resource.identity(version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp, responseHandler: handler).then(on: q) {
			return try self.decoder.decode(Identity.self, from: $0)
		}
	}
	
	/// Asynchronously retrieves information about org limits
	/// - Returns: Promise of a dictionary of Limits, keyed by limit name
	/// See https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_limits.htm
	open func limits() -> Promise<[String:Limit]> {
		let resource = Resource.limits(version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp).then(on: q) {
			return try self.decoder.decode([String:Limit].self, from: $0)
		}
	}
	
	/// Asynchronsouly executes a SOQL query.
	/// See https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_query.htm
	/// - Parameter soql: SOQL query
	/// - Returns: Promise of a QueryResult whose records, if any, are decoded as generic type 'T'
	open func query<T: Decodable>(soql: String) -> Promise<QueryResult<T>> {
		let resource = Resource.query(soql: soql, version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp).then(on: q) {
			return try self.decoder.decode(QueryResult<T>.self, from: $0)
		}
	}
	
	/// Asynchronsouly executes a SOQL query
	/// See https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_query.htm
	/// - Parameter soql: SOQL query
	/// - Returns: Promise of a QueryResult whose records, if any, are decoded as SObjects
	open func query(soql: String) -> Promise<QueryResult<SObject>> {
		let resource = Resource.query(soql: soql, version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp).then(on: q) {
			return try self.decoder.decode(QueryResult<SObject>.self, from: $0)
		}
	}
	
	/// Asynchronsouly executes multiple SOQL queries.
	/// See https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_query.htm
	/// - Parameter soql: Array of SOQL queries
	/// - Returns: Promise of an array of QueryResults, in the same order as the "soql" parameter
	open func query<T: Decodable>(soql: [String]) -> Promise<[QueryResult<T>]> {
		let promises: [Promise<QueryResult<T>>] = soql.map { query(soql: $0) }
		return when(fulfilled: promises)
	}
	
	/// Asynchronsouly executes multiple SOQL queries (non-generic function version).
	/// See https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_query.htm
	/// - Parameter soql: Array of SOQL queries
	/// - Returns: Promise of an array of QueryResults, in the same order as the "soql" parameter
	open func query(soql: [String]) -> Promise<[QueryResult<SObject>]> {
		let promises: [Promise<QueryResult<SObject>>] = soql.map { query(soql: $0) }
		return when(fulfilled: promises)
	}
	
	/// Queries next pages of records returned by a SOQL query whose result is broken into multiple pages.
	/// See https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_query.htm
	/// - Parameter path: the 'nextRecordsPath' property of a previously-obtained QueryResult.
	/// - Returns: Promise of a QueryResult
	open func queryNext<T: Decodable>(path: String) -> Promise<QueryResult<T>> {
		let resource = Resource.queryNext(path: path)
		return requestor.request(resource: resource, connectedApp: connectedApp).then(on: q) {
			return try self.decoder.decode(QueryResult<T>.self, from: $0)
		}
	}
	
	/// Queries next page of records returned by a SOQL query whose result is broken into pages.
	/// See https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_query.htm
	/// - Parameter path: the 'nextRecordsPath' property of a previously-obtained QueryResult.
	/// - Returns: Promise of a QueryResult
	open func queryNext(path: String) -> Promise<QueryResult<SObject>> {
		let resource = Resource.queryNext(path: path)
		return requestor.request(resource: resource, connectedApp: connectedApp).then(on: q) {
			return try self.decoder.decode(QueryResult<SObject>.self, from: $0)
		}
	}
	
	/// Asynchronously retrieves a single record.
	/// - Parameter type: The type of the record, e.g. "Account", "Contact" or "MyCustomObject__c"
	/// - Parameter id: ID of the record to retrieve
	/// - Parameter fields: Optional array of field names to retrieve. If nil, all fields will be retrieved
	/// - Returns: Promise of a dictionary keyed by field names (aka "Record")
	open func retrieve<T: Decodable>(type: String, id: String, fields: [String]? = nil) -> Promise<T> {
		let resource = Resource.retrieve(type: type, id: id, fields: fields, version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp).then(on: q) {
			return try self.decoder.decode(T.self, from: $0)
		}
	}
	
	/// Asynchronously retrieves a single record (non-generic function version).
	/// - Parameter type: The type of the record, e.g. "Account", "Contact" or "MyCustomObject__c"
	/// - Parameter id: ID of the record to retrieve
	/// - Parameter fields: Optional array of field names to retrieve. If nil, all fields will be retrieved
	/// - Returns: Promise of a dictionary keyed by field names (aka "Record")
	open func retrieve(type: String, id: String, fields: [String]? = nil) -> Promise<SObject> {
		let resource = Resource.retrieve(type: type, id: id, fields: fields, version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp).then(on: q) {
			return try self.decoder.decode(SObject.self, from: $0)
		}
	}
	
	/// Asynchronously retrieves multiple records of the same type, by ID.
	/// - Parameter type: The type of the records to retrieve, e.g. "Account", "Contact" or "MyCustomObject__c"
	/// - Parameter ids: IDs of the records to retrieve. All records must be of the same type.
	/// - Parameter fields: Optional array of field names to retrieve. If nil, all fields will be retrieved
	/// - Returns: Promise of an array of dictionaries, keyed by field names, and in the same order as the "ids" parameter
	open func retrieve<T: Decodable>(type: String, ids: [String], fields: [String]? = nil) -> Promise<[T]> {
		let promises: [Promise<T>] = ids.map { retrieve(type: type, id: $0, fields: fields) }
		return when(fulfilled: promises)
	}
	
	/// Asynchronously retrieves multiple records of the same type, by ID (non-generic version).
	/// - Parameter type: The type of the records to retrieve, e.g. "Account", "Contact" or "MyCustomObject__c"
	/// - Parameter ids: IDs of the records to retrieve. All records must be of the same type.
	/// - Parameter fields: Optional array of field names to retrieve. If nil, all fields will be retrieved
	/// - Returns: Promise of an array of dictionaries, keyed by field names, and in the same order as the "ids" parameter
	open func retrieve(type: String, ids: [String], fields: [String]? = nil) -> Promise<[SObject]> {
		let promises: [Promise<SObject>] = ids.map { retrieve(type: type, id: $0, fields: fields) }
		return when(fulfilled: promises)
	}
	
	/// Asynchronously creates a new record in Salesforce
	/// - Parameter type: The type of the record to be inserted, e.g. "Account", "Contact" or "MyCustomObject__c"
	/// - Parameter fields: Dictionary of field names and values to be set on the newly-inserted record.
	/// - Returns: Promise of a string which holds the ID of the newly-inserted record
	open func insert(type: String, fields: [String: Any?]) -> Promise<String> {
		let resource = Resource.insert(type: type, fields: fields, version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp).then(on: q) {
			(data: Data) -> String in
			struct InsertResult: Decodable {
				var id: String
			}
			let result: InsertResult = try self.decoder.decode(InsertResult.self, from: data)
			return result.id
		}
	}
	
	/// Asynchronously updates a record in Salesforce
	/// - Parameter type: Type of record to be updated (for example, "Account" or "Lead")
	/// - Parameter id: Unique ID of record to be updated
	/// - Parameter fields: Dictionary of field name and field value pairs.
	/// - Returns: Promise<Void>
	open func update(type: String, id: String, fields: [String: Any?]) -> Promise<Void> {
		let resource = Resource.update(type: type, id: id, fields: fields, version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp).asVoid()
	}
	
	/// Asynchronously deletes a record
	/// - Parameter type: Type of record to be deleted (for example, "Account" or "Lead")
	/// - Parameter id: Unique ID of record to be deleted
	/// - Returns: Promise<Void>
	open func delete(type: String, id: String) -> Promise<Void> {
		let resource = Resource.delete(type: type, id: id, version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp).asVoid()
	}
	
	/// Asynchronously retrieves metadata about a Salesforce object and its fields.
	/// See: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_sobject_describe.htm
	/// - Parameter type: Object name
	/// - Returns: Promise<ObjectDescription>
	open func describe(type: String) -> Promise<ObjectMetadata> {
		let resource = Resource.describe(type: type, version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp).then(on: q) {
			return try self.decoder.decode(ObjectMetadata.self, from: $0)
		}
	}
	
	/// Asynchronously retrieves metadata for multiple Salesforce objects.
	/// - Parameter types: Array of object names
	/// - Returns: Promise<[ObjectDescription]>, a promise of an array of ObjectDescriptions, in the same order as the "types" parameter.
	open func describe(types: [String]) -> Promise<[ObjectMetadata]> {
		let promises = types.map { describe(type: $0) }
		return when(fulfilled: promises)
	}
	
	/// Asynchronously retrieves object-level metadata about all objects defined in the org.
	/// See: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_describeGlobal.htm
	/// - Returns: Promise of an array of ObjectDescriptions
	open func describeAll() -> Promise<[ObjectMetadata]> {
		let resource = Resource.describeGlobal(version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp).then(on: q) {
			(data: Data) -> [ObjectMetadata] in
			struct DescribeAllResult: Decodable {
				var sobjects: [ObjectMetadata]
			}
			let result: DescribeAllResult = try self.decoder.decode(DescribeAllResult.self, from: data)
			return result.sobjects
		}
	}
	
	/// Asynchronously retrieves an image at the given path.
	/// Use this method only for small images, e.g. images at Account.PhotoUrl, Contact.PhotoUrl, or Lead.PhotoUrl.
	/// - Parameter path: path relative to the user's instance URL
	/// - Returns: Promise of an image
	open func fetchImage(path: String) -> Promise<UIImage> {
		let resource = Resource.custom(method: .get, baseURL: nil, path: path, parameters: nil, headers: ["Accept": "image/*"])
		return requestor.request(resource: resource, connectedApp: connectedApp).asImage(on: q)
	}
	
	/// Asynchronously retrieves an image at the given path.
	/// Use this method only for small images, e.g. User.SmallPhotoUrl or User.FullPhotoUrl.
	/// - Parameter url: URL to the image to be retrieved
	/// - Returns: Promise of an image
	open func fetchImage(url: URL) -> Promise<UIImage> {
		let resource = Resource.custom(method: .get, baseURL: url, path: nil, parameters: nil, headers: ["Accept": "image/*"])
		return requestor.request(resource: resource, connectedApp: connectedApp).asImage(on: q)
	}
	
	/// Use this method to register your device to receive push notifications from the Salesforce Universal Push Notification service.
	/// - Parameter devicetoken: the device token returned from a successful UIApplication.shared.registerForRemoteNotification() invocation.
	/// - Returns: Promise of a String which holds the ID of the newly-inserted MobilePushServiceDevice record
	open func registerForNotifications(deviceToken: String) -> Promise<String> {
		let resource = Resource.registerForNotifications(deviceToken: deviceToken, version: version)
		return requestor.request(resource: resource, connectedApp: connectedApp).then(on: q) {
			(data: Data) -> String in
			struct InsertResult: Decodable {
				var id: String
			}
			let result: InsertResult = try self.decoder.decode(InsertResult.self, from: data)
			return result.id
		}
	}
		
	/// Asynchronously calls an Apex method exposed as a REST endpoint.
	/// See https://developer.salesforce.com/page/Creating_REST_APIs_using_Apex_REST
	/// - Parameter method: HTTP method
	/// - Parameter path: String that gets appended to instance URL; should begin with "/"
	/// - Parameter parameters: Dictionary of parameter name/value pairs
	/// - Parameter headers: Dictionary of HTTP header values
	/// - Returns: Promise of Data
	open func apex(method: Resource.HTTPMethod = .get, path: String, parameters: [String: Any]? = nil, headers: [String: String]? = nil) -> Promise<Data> {
		let resource = Resource.apex(method: method, path: path, parameters: parameters, headers: headers)
		return requestor.request(resource: resource, connectedApp: connectedApp)
	}

	/// Use this method to call a Salesforce REST API endpoint that's not covered by the other methods.
	/// Note: baseURL and path should not both be nil
	/// - Parameter method: HTTP method
	/// - Parameter baseURL: Base URL to which the path parameter will be appended. If nil, then user's "instance URL" will be used
	/// - Parameter path: Absolute path to endpoint, relative to "baseURL" parameter or, if "baseURL" is nil, then relative to the user's "instance URL"
	/// - Parameter parameters: Dictionary of parameter name/value pairs
	/// - Parameter headers: Dictionary of HTTP header values
	/// - Returns: Promise of Data
	open func custom(method: Resource.HTTPMethod = .get, baseURL: URL? = nil, path: String? = nil, parameters: [String: Any]? = nil, headers: [String: String]? = nil) -> Promise<Data> {
		let resource = Resource.custom(method: method, baseURL: baseURL, path: path, parameters: parameters, headers: headers)
		return requestor.request(resource: resource, connectedApp: connectedApp)
	}
}