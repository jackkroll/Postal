import Foundation

enum PreviewData {
    // MARK: - Dates

    private static let referenceDate = Date(timeIntervalSince1970: 1_720_512_000) // Jul 9, 2024

    static func daysAgo(_ days: Int, hour: Int = 12) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = hour
        let base = Calendar.current.date(from: components) ?? referenceDate
        return Calendar.current.date(byAdding: .day, value: -days, to: base) ?? base
    }

    static func hoursAgo(_ hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: -hours, to: referenceDate) ?? referenceDate
    }

    // MARK: - Post Offices

    static let mainStreetPostOffice = PostOffice(id: 1, name: "Main Street Post Office", lat: 37.7749, lon: -122.4194, tier: 0)
    static let centralSortingFacility = PostOffice(id: 42, name: "Central Sorting Facility", lat: 41.8781, lon: -87.6298, tier: 1)
    static let riversideStation = PostOffice(id: 87, name: "Riverside Station", lat: 33.9533, lon: -117.3962, tier: 2)
    static let westsideDeliveryOffice = PostOffice(id: 156, name: "Westside Delivery Office", lat: 34.0522, lon: -118.2437, tier: 3)

    static let postOffices = [mainStreetPostOffice, centralSortingFacility, riversideStation, westsideDeliveryOffice]

    // MARK: - Locations

    static let mainStreetLocation = Location(
        code: mainStreetPostOffice.id,
        name: mainStreetPostOffice.name,
        latitude: mainStreetPostOffice.lat ?? 0,
        longitude: mainStreetPostOffice.lon ?? 0,
        tier: mainStreetPostOffice.tier ?? 0
    )

    static let westsideLocation = Location(
        code: westsideDeliveryOffice.id,
        name: westsideDeliveryOffice.name,
        latitude: westsideDeliveryOffice.lat ?? 0,
        longitude: westsideDeliveryOffice.lon ?? 0,
        tier: westsideDeliveryOffice.tier ?? 0
    )

    static let riversideLocation = Location(
        code: riversideStation.id,
        name: riversideStation.name,
        latitude: riversideStation.lat ?? 0,
        longitude: riversideStation.lon ?? 0,
        tier: riversideStation.tier ?? 0
    )

    // MARK: - Mailboxes

    static let ownedMailboxes: [MailboxSummary] = [
        MailboxSummary(
            id: MailboxID(postOfficeID: mainStreetPostOffice.id, code: "7XK9M"),
            postOfficeID: mainStreetPostOffice.id,
            postOfficeName: mainStreetPostOffice.name,
            label: "Box #12",
            ownerUserID: "preview-user-id",
            owned: true
        ),
        MailboxSummary(
            id: MailboxID(postOfficeID: westsideDeliveryOffice.id, code: "HOME1"),
            postOfficeID: westsideDeliveryOffice.id,
            postOfficeName: westsideDeliveryOffice.name,
            label: "Box #91",
            ownerUserID: "preview-user-id",
            owned: true
        ),
    ]

    static let destinationMailboxes: [MailboxSummary] = [
        MailboxSummary(
            id: MailboxID(postOfficeID: mainStreetPostOffice.id, code: "2ABC1"),
            postOfficeID: mainStreetPostOffice.id,
            postOfficeName: mainStreetPostOffice.name,
            label: "Box #47",
            ownerUserID: "other-user",
            owned: false
        ),
        MailboxSummary(
            id: MailboxID(postOfficeID: mainStreetPostOffice.id, code: "9ZZZ9"),
            postOfficeID: mainStreetPostOffice.id,
            postOfficeName: mainStreetPostOffice.name,
            label: "Box #3",
            ownerUserID: "other-user-2",
            owned: false
        ),
        MailboxSummary(
            id: MailboxID(postOfficeID: riversideStation.id, code: "RIV22"),
            postOfficeID: riversideStation.id,
            postOfficeName: riversideStation.name,
            label: "Box #22",
            ownerUserID: "other-user-3",
            owned: false
        ),
        MailboxSummary(
            id: MailboxID(postOfficeID: westsideDeliveryOffice.id, code: "OUT105"),
            postOfficeID: westsideDeliveryOffice.id,
            postOfficeName: westsideDeliveryOffice.name,
            label: "Box #105",
            ownerUserID: "other-user-4",
            owned: false
        ),
        MailboxSummary(
            id: MailboxID(postOfficeID: riversideStation.id, code: "FAIL55"),
            postOfficeID: riversideStation.id,
            postOfficeName: riversideStation.name,
            label: "Box #55",
            ownerUserID: "other-user-5",
            owned: false
        ),
    ]

    static var allMailboxes: [MailboxSummary] {
        ownedMailboxes + destinationMailboxes
    }

    // MARK: - Address Book

    static let addressBookEntries: [AddressBookEntrySummary] = [
        AddressBookEntrySummary(
            id: "addr-entry-1",
            nickname: "Alex",
            mailboxID: destinationMailboxes[0].id,
            notes: "College roommate",
            postOfficeID: destinationMailboxes[0].postOfficeID,
            postOfficeName: destinationMailboxes[0].postOfficeName,
            mailboxLabel: destinationMailboxes[0].label,
            createdAt: daysAgo(30),
            updatedAt: daysAgo(5)
        ),
        AddressBookEntrySummary(
            id: "addr-entry-2",
            nickname: "Jordan",
            mailboxID: destinationMailboxes[1].id,
            notes: nil,
            postOfficeID: destinationMailboxes[1].postOfficeID,
            postOfficeName: destinationMailboxes[1].postOfficeName,
            mailboxLabel: destinationMailboxes[1].label,
            createdAt: daysAgo(14),
            updatedAt: daysAgo(14)
        ),
        AddressBookEntrySummary(
            id: "addr-entry-3",
            nickname: "Sam (Riverside)",
            mailboxID: destinationMailboxes[2].id,
            notes: "Sends letters every few weeks",
            postOfficeID: destinationMailboxes[2].postOfficeID,
            postOfficeName: destinationMailboxes[2].postOfficeName,
            mailboxLabel: destinationMailboxes[2].label,
            createdAt: daysAgo(7),
            updatedAt: hoursAgo(12)
        ),
        AddressBookEntrySummary(
            id: "addr-entry-4",
            nickname: "Westside Drop",
            mailboxID: destinationMailboxes[3].id,
            notes: "Work contact",
            postOfficeID: destinationMailboxes[3].postOfficeID,
            postOfficeName: destinationMailboxes[3].postOfficeName,
            mailboxLabel: destinationMailboxes[3].label,
            createdAt: daysAgo(2),
            updatedAt: daysAgo(2)
        ),
    ]

    // MARK: - Tracking Numbers

    static let inTransitTrackingNumber = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    static let deliveredTrackingNumber = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
    static let awaitingPickupTrackingNumber = "6ba7b811-9dad-11d1-80b4-00c04fd430c8"
    static let failedTrackingNumber = "6ba7b812-9dad-11d1-80b4-00c04fd430c8"

    // MARK: - Letter Summaries

    static let sampleLetterText = """
    Dear friend,

    Hope this note finds you well. The weather has been lovely here — warm afternoons and cool evenings.

    Write back when you can.
    """

    static let deliveredLetterMetadata = LetterMetadata(
        format: .text,
        mimeType: "text/plain",
        encoding: nil,
        filename: nil,
        byteSize: sampleLetterText.utf8.count
    )

    static let letterInTransit = LetterSummary(
        trackingNumber: inTransitTrackingNumber,
        origin: LetterEndpoint(mailboxID: ownedMailboxes[0].id),
        destination: LetterEndpoint(mailboxID: destinationMailboxes[0].id),
        status: .inTransit,
        hasLetter: true,
        letterFormat: .text,
        letterMimeType: "text/plain",
        letterEncoding: nil,
        letterByteSize: sampleLetterText.utf8.count,
        createdAt: daysAgo(3),
        updatedAt: hoursAgo(2)
    )

    static let letterDelivered = LetterSummary(
        trackingNumber: deliveredTrackingNumber,
        origin: LetterEndpoint(mailboxID: ownedMailboxes[1].id),
        destination: LetterEndpoint(mailboxID: destinationMailboxes[1].id),
        status: .delivered,
        hasLetter: true,
        letterFormat: .text,
        letterMimeType: "text/plain",
        letterEncoding: nil,
        letterByteSize: sampleLetterText.utf8.count,
        createdAt: daysAgo(7),
        updatedAt: daysAgo(1)
    )

    static let letterAwaitingPickup = LetterSummary(
        trackingNumber: awaitingPickupTrackingNumber,
        origin: LetterEndpoint(mailboxID: ownedMailboxes[0].id),
        destination: LetterEndpoint(mailboxID: destinationMailboxes[2].id),
        status: .awaitingPickup,
        hasLetter: true,
        letterFormat: .text,
        letterMimeType: "text/plain",
        letterEncoding: nil,
        letterByteSize: sampleLetterText.utf8.count,
        createdAt: hoursAgo(1),
        updatedAt: hoursAgo(1)
    )

    static let letterOutForDelivery = LetterSummary(
        trackingNumber: "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
        origin: LetterEndpoint(mailboxID: ownedMailboxes[0].id),
        destination: LetterEndpoint(mailboxID: destinationMailboxes[3].id),
        status: .outForDelivery,
        hasLetter: false,
        letterFormat: nil,
        letterMimeType: nil,
        letterEncoding: nil,
        letterByteSize: nil,
        createdAt: daysAgo(2),
        updatedAt: hoursAgo(4)
    )

    static let letterFailed = LetterSummary(
        trackingNumber: failedTrackingNumber,
        origin: LetterEndpoint(mailboxID: ownedMailboxes[1].id),
        destination: LetterEndpoint(mailboxID: destinationMailboxes[4].id),
        status: .failed,
        hasLetter: true,
        letterFormat: .image,
        letterMimeType: "image/png",
        letterEncoding: nil,
        letterByteSize: 12_400,
        createdAt: daysAgo(5),
        updatedAt: daysAgo(2)
    )

    static let letters: [LetterSummary] = [
        letterInTransit,
        letterOutForDelivery,
        letterAwaitingPickup,
        letterDelivered,
        letterFailed,
    ]

    // MARK: - Inbound Letters

    static let inboundLetters: [InboundLetterItem] = [
        InboundLetterItem(
            id: "inbound-in-transit",
            trackingNumber: inTransitTrackingNumber,
            status: .inTransit,
            originName: riversideStation.name,
            destinationName: mainStreetPostOffice.name,
            hasLetter: true,
            letterFormat: .text,
            createdAt: daysAgo(2),
            updatedAt: hoursAgo(3)
        ),
        InboundLetterItem(
            id: "inbound-delivered",
            trackingNumber: deliveredTrackingNumber,
            status: .delivered,
            originName: westsideDeliveryOffice.name,
            destinationName: mainStreetPostOffice.name,
            hasLetter: true,
            letterFormat: .text,
            createdAt: daysAgo(6),
            updatedAt: daysAgo(1)
        ),
        InboundLetterItem(
            id: "inbound-out-for-delivery",
            trackingNumber: "b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
            status: .outForDelivery,
            originName: centralSortingFacility.name,
            destinationName: westsideDeliveryOffice.name,
            hasLetter: false,
            createdAt: daysAgo(1),
            updatedAt: hoursAgo(5)
        ),
    ]

    // MARK: - Tracking Info

    static let trackingInfoInTransit = TrackingInfo(
        status: .inTransit,
        destination: LetterEndpoint(mailboxID: destinationMailboxes[0].id),
        origin: LetterEndpoint(mailboxID: ownedMailboxes[0].id),
        trackingNumber: inTransitTrackingNumber
    )

    // MARK: - Tracking Routes

    static let routeInTransit = TrackingRoute(
        trackingNumber: inTransitTrackingNumber,
        status: .inTransit,
        routeFound: true,
        currentFacility: riversideStation,
        timeline: [
            RouteTimelineEntry(facilityID: 1, tier: 0, arrival: daysAgo(3, hour: 9), departure: daysAgo(3, hour: 10)),
            RouteTimelineEntry(facilityID: 42, tier: 1, arrival: daysAgo(2, hour: 14), departure: daysAgo(2, hour: 16)),
            RouteTimelineEntry(facilityID: 87, tier: 2, arrival: hoursAgo(6), departure: nil),
        ],
        events: [
            ShipmentTrackingEvent(
                eventType: "picked_up",
                facility: mainStreetPostOffice,
                facilityID: 1,
                scheduledFor: nil,
                recordedAt: daysAgo(3, hour: 9)
            ),
            ShipmentTrackingEvent(
                eventType: "departed_facility",
                facility: mainStreetPostOffice,
                facilityID: 1,
                scheduledFor: nil,
                recordedAt: daysAgo(3, hour: 10)
            ),
            ShipmentTrackingEvent(
                eventType: "arrived_facility",
                facility: centralSortingFacility,
                facilityID: 42,
                scheduledFor: nil,
                recordedAt: daysAgo(2, hour: 14)
            ),
            ShipmentTrackingEvent(
                eventType: "departed_facility",
                facility: centralSortingFacility,
                facilityID: 42,
                scheduledFor: nil,
                recordedAt: daysAgo(2, hour: 16)
            ),
            ShipmentTrackingEvent(
                eventType: "arrived_facility",
                facility: riversideStation,
                facilityID: 87,
                scheduledFor: nil,
                recordedAt: hoursAgo(6)
            ),
            ShipmentTrackingEvent(
                eventType: "departed_facility",
                facility: riversideStation,
                facilityID: 87,
                scheduledFor: nil,
                recordedAt: hoursAgo(2)            ),
        ]
    )

    static let routeDelivered = TrackingRoute(
        trackingNumber: deliveredTrackingNumber,
        status: .delivered,
        routeFound: true,
        currentFacility: westsideDeliveryOffice,
        timeline: [
            RouteTimelineEntry(facilityID: 1, tier: 0, arrival: daysAgo(7, hour: 8), departure: daysAgo(7, hour: 9)),
            RouteTimelineEntry(facilityID: 156, tier: 3, arrival: daysAgo(1, hour: 11), departure: daysAgo(1, hour: 12)),
        ],
        events: [
            ShipmentTrackingEvent(
                eventType: "picked_up",
                facility: mainStreetPostOffice,
                facilityID: 1,
                scheduledFor: nil,
                recordedAt: daysAgo(7, hour: 8)
            ),
            ShipmentTrackingEvent(
                eventType: "delivered",
                facility: westsideDeliveryOffice,
                facilityID: 156,
                scheduledFor: nil,
                recordedAt: daysAgo(1, hour: 12)
            ),
        ]
    )

    static let routeAwaitingPickup = TrackingRoute(
        trackingNumber: awaitingPickupTrackingNumber,
        status: .awaitingPickup,
        routeFound: true,
        currentFacility: mainStreetPostOffice,
        timeline: [],
        events: [
            ShipmentTrackingEvent(
                eventType: "created",
                facility: mainStreetPostOffice,
                facilityID: 1,
                scheduledFor: nil,
                recordedAt: hoursAgo(1)
            ),
        ]
    )

    static let routeNoRouteFound = TrackingRoute(
        trackingNumber: "00000000-0000-0000-0000-000000000000",
        status: .failed,
        routeFound: false,
        currentFacility: nil,
        timeline: [],
        events: []
    )
}

// MARK: - TrackingRoute memberwise initializer for previews

private extension TrackingRoute {
    init(
        trackingNumber: String,
        status: ShipmentStatus,
        routeFound: Bool,
        currentFacility: PostOffice?,
        timeline: [RouteTimelineEntry],
        events: [ShipmentTrackingEvent]
    ) {
        self.trackingNumber = trackingNumber
        self.status = status
        self.routeFound = routeFound
        self.currentFacility = currentFacility
        self.timeline = timeline
        self.events = events
    }
}
