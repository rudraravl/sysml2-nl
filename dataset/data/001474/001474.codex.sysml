package IntegratedLibrarySystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def ISBN {
        attribute prefix: String;
        attribute registrationGroup: String;
        attribute registrant: String;
        attribute publication: String;
        attribute checkDigit: String;
    }

    attribute def LibraryCardNumber {
        attribute value: String;
    }

    attribute def EmailAddress {
        attribute value: String;
    }

    attribute def CurrencyAmount {
        attribute amount: Real;
        attribute currencyCode: String;
    }

    attribute def CalendarDate {
        attribute year: Integer;
        attribute month: Integer;
        attribute day: Integer;
    }

    attribute def DateTimeStamp {
        attribute iso8601: String;
    }

    attribute def LoanDuration {
        attribute days: Integer;
    }

    enum def ItemStatus {
        enum available;
        enum checkedOut;
        enum onHold;
        enum inTransit;
        enum lost;
        enum maintenance;
        enum retired;
    }

    enum def PatronStatus {
        enum active;
        enum suspended;
        enum expired;
        enum blocked;
    }

    enum def NotificationChannel {
        enum email;
        enum sms;
        enum inApp;
        enum printedNotice;
    }

    enum def PaymentStatus {
        enum unpaid;
        enum pending;
        enum paid;
        enum waived;
        enum disputed;
    }

    item def CatalogSearchRequest {
        attribute queryText: String;
        attribute requestingBranchId: String;
        attribute includeUnavailable: Boolean;
        attribute maxResults: Integer;
    }

    item def CatalogSearchResult {
        attribute title: String;
        attribute author: String;
        attribute isbn: ISBN;
        attribute holdingsAvailable: Integer;
        attribute holdingsTotal: Integer;
        attribute locationSummary: String;
    }

    item def PatronCredential {
        attribute cardNumber: LibraryCardNumber;
        attribute pinHash: String;
    }

    item def PatronProfile {
        attribute patronId: String;
        attribute fullName: String;
        attribute email: EmailAddress;
        attribute status: PatronStatus;
        attribute homeBranchId: String;
        attribute activeLoans: Integer;
        attribute outstandingFees: CurrencyAmount;
    }

    item def LibraryMaterial {
        attribute itemId: String;
        attribute bibliographicId: String;
        attribute title: String;
        attribute creator: String;
        attribute isbn: ISBN;
        attribute status: ItemStatus;
        attribute owningBranchId: String;
        attribute shelfLocation: String;
        attribute replacementCost: CurrencyAmount;
    }

    item def LoanRecord {
        attribute loanId: String;
        attribute itemId: String;
        attribute patronId: String;
        attribute checkoutTime: DateTimeStamp;
        attribute dueDate: CalendarDate;
        attribute renewalCount: Integer;
    }

    item def HoldRequest {
        attribute holdId: String;
        attribute bibliographicId: String;
        attribute patronId: String;
        attribute preferredBranchId: String;
        attribute requestTime: DateTimeStamp;
        attribute queuePosition: Integer;
    }

    item def FineAssessment {
        attribute fineId: String;
        attribute patronId: String;
        attribute itemId: String;
        attribute amount: CurrencyAmount;
        attribute reason: String;
        attribute assessedDate: CalendarDate;
        attribute paymentStatus: PaymentStatus;
    }

    item def NotificationMessage {
        attribute recipientPatronId: String;
        attribute channel: NotificationChannel;
        attribute subject: String;
        attribute body: String;
        attribute createdAt: DateTimeStamp;
    }

    port def SearchServicePort {
        in item searchRequest: CatalogSearchRequest;
        out item searchResult: CatalogSearchResult;
    }

    port def AuthenticationPort {
        in item credential: PatronCredential;
        out item profile: PatronProfile;
    }

    port def CirculationCommandPort {
        in item credential: PatronCredential;
        in item material: LibraryMaterial;
        out item loan: LoanRecord;
        out item fine: FineAssessment;
    }

    port def HoldManagementPort {
        in item credential: PatronCredential;
        in item request: HoldRequest;
        out item updatedRequest: HoldRequest;
        out item notification: NotificationMessage;
    }

    port def NotificationPort {
        in item message: NotificationMessage;
        out attribute accepted: Boolean;
    }

    port def PaymentPort {
        in item fine: FineAssessment;
        out attribute paymentAccepted: Boolean;
    }

    part def CatalogSubsystem {
        attribute indexedTitles: Integer;
        attribute indexedItems: Integer;
        attribute averageSearchLatency: Real;
        port publicSearch: SearchServicePort;
        port staffSearch: SearchServicePort;

        action searchCatalog {
            in item request: CatalogSearchRequest;
            out item result: CatalogSearchResult;
        }
    }

    part def PatronAccountSubsystem {
        attribute registeredPatrons: Integer;
        attribute maxActiveLoansPerPatron: Integer = 50;
        port authentication: AuthenticationPort;

        action authenticatePatron {
            in item credential: PatronCredential;
            out item profile: PatronProfile;
        }

        state def PatronAccountLifecycle {
            state active;
            state suspended;
            state expired;
            state blocked;

            transition active_to_suspended first active then suspended;
            transition suspended_to_active first suspended then active;
            transition active_to_expired first active then expired;
            transition expired_to_active first expired then active;
            transition any_to_blocked first active then blocked;
        }
    }

    part def CirculationSubsystem {
        attribute standardLoanPeriod: LoanDuration;
        attribute maximumRenewals: Integer = 3;
        attribute overdueFinePerDay: CurrencyAmount;
        port circulationCommands: CirculationCommandPort;

        action checkoutItem {
            in item credential: PatronCredential;
            in item material: LibraryMaterial;
            out item loan: LoanRecord;
        }

        action returnItem {
            in item material: LibraryMaterial;
            out item fine: FineAssessment;
        }

        action renewLoan {
            in item loan: LoanRecord;
            out item renewedLoan: LoanRecord;
        }

        state def MaterialCirculationLifecycle {
            state available;
            state checkedOut;
            state onHold;
            state inTransit;
            state lost;
            state retired;

            transition checkout first available then checkedOut;
            transition returnToShelf first checkedOut then available;
            transition fulfillHold first available then onHold;
            transition branchTransfer first available then inTransit;
            transition receiveTransfer first inTransit then available;
            transition declareLost first checkedOut then lost;
            transition retireLostItem first lost then retired;
        }
    }

    part def HoldSubsystem {
        attribute activeHolds: Integer;
        attribute holdPickupWindow: LoanDuration;
        port holds: HoldManagementPort;

        action placeHold {
            in item credential: PatronCredential;
            in item request: HoldRequest;
            out item queuedRequest: HoldRequest;
        }

        action releaseHold {
            in item request: HoldRequest;
            out item notice: NotificationMessage;
        }
    }

    part def BranchOperationsSubsystem {
        attribute branchCount: Integer;
        attribute openServiceDesks: Integer;
        port staffCirculation: CirculationCommandPort;
        port staffSearch: SearchServicePort;
    }

    part def DigitalAccessSubsystem {
        attribute activeSessions: Integer;
        attribute webAvailabilityPercent: Real;
        port patronLogin: AuthenticationPort;
        port onlineSearch: SearchServicePort;
        port onlineHolds: HoldManagementPort;
        port onlinePayments: PaymentPort;
    }

    part def NotificationSubsystem {
        attribute messagesSentToday: Integer;
        attribute deliverySuccessPercent: Real;
        port outboundNotifications: NotificationPort;

        action sendNotice {
            in item message: NotificationMessage;
            out attribute accepted: Boolean;
        }
    }

    part def FinancialSubsystem {
        attribute unpaidBalanceTotal: CurrencyAmount;
        attribute paymentsProcessedToday: Integer;
        port paymentProcessing: PaymentPort;

        action assessFine {
            in item loan: LoanRecord;
            out item fine: FineAssessment;
        }

        action processPayment {
            in item fine: FineAssessment;
            out attribute paymentAccepted: Boolean;
        }
    }

    part def IntegratedLibrarySystem {
        attribute systemName: String = "Integrated Library System";
        attribute primaryFunction: String = "Coordinate catalog discovery, patron identity, circulation, holds, notifications, and fee management across physical and digital library services.";
        attribute participatingBranches: Integer;
        attribute catalogRecordCount: Integer;
        attribute physicalItemCount: Integer;
        attribute digitalItemCount: Integer;
        attribute targetAvailabilityPercent: Real = 99.9;

        part catalog: CatalogSubsystem {
            attribute indexedTitles = 250000;
            attribute indexedItems = 840000;
            attribute averageSearchLatency = 0.45;
        }

        part patronAccounts: PatronAccountSubsystem {
            attribute registeredPatrons = 180000;
        }

        part circulation: CirculationSubsystem {
            attribute standardLoanPeriod {
                attribute days = 21;
            }
            attribute overdueFinePerDay {
                attribute amount = 0.25;
                attribute currencyCode = "USD";
            }
        }

        part holds: HoldSubsystem {
            attribute activeHolds = 46000;
            attribute holdPickupWindow {
                attribute days = 7;
            }
        }

        part branches: BranchOperationsSubsystem {
            attribute branchCount = 24;
            attribute openServiceDesks = 38;
        }

        part digitalAccess: DigitalAccessSubsystem {
            attribute activeSessions = 3200;
            attribute webAvailabilityPercent = 99.95;
        }

        part notifications: NotificationSubsystem {
            attribute messagesSentToday = 12850;
            attribute deliverySuccessPercent = 98.7;
        }

        part finance: FinancialSubsystem {
            attribute paymentsProcessedToday = 415;
            attribute unpaidBalanceTotal {
                attribute amount = 37250.75;
                attribute currencyCode = "USD";
            }
        }

        port publicCatalog: SearchServicePort;
        port patronIdentity: AuthenticationPort;
        port circulationDesk: CirculationCommandPort;
        port holdRequests: HoldManagementPort;
        port notices: NotificationPort;
        port payments: PaymentPort;

        connect publicCatalog to catalog.publicSearch;
        connect patronIdentity to patronAccounts.authentication;
        connect circulationDesk to circulation.circulationCommands;
        connect holdRequests to holds.holds;
        connect notices to notifications.outboundNotifications;
        connect payments to finance.paymentProcessing;

        connect digitalAccess.onlineSearch to catalog.publicSearch;
        connect digitalAccess.patronLogin to patronAccounts.authentication;
        connect digitalAccess.onlineHolds to holds.holds;
        connect digitalAccess.onlinePayments to finance.paymentProcessing;

        connect branches.staffSearch to catalog.staffSearch;
        connect branches.staffCirculation to circulation.circulationCommands;

        action performPrimaryLibraryService {
            in item credential: PatronCredential;
            in item searchRequest: CatalogSearchRequest;
            out item patron: PatronProfile;
            out item result: CatalogSearchResult;

            first start;
            then authenticate;
            then discover;
            then presentAvailability;
            then done;

            action authenticate {
                in item credential;
                out item patron;
            }

            action discover {
                in item searchRequest;
                out item result;
            }

            action presentAvailability {
                in item patron;
                in item result;
            }
        }

        action borrowAvailableMaterial {
            in item credential: PatronCredential;
            in item material: LibraryMaterial;
            out item loan: LoanRecord;
            out item message: NotificationMessage;

            first validatePatron;
            then verifyAvailability;
            then createLoan;
            then updateInventoryStatus;
            then notifyPatron;
            then completeCheckout;

            action validatePatron {
                in item credential;
                out item patron: PatronProfile;
            }

            action verifyAvailability {
                in item material;
                out attribute available: Boolean;
            }

            action createLoan {
                in item material;
                in item patron: PatronProfile;
                out item loan;
            }

            action updateInventoryStatus {
                in item material;
            }

            action notifyPatron {
                in item loan;
                out item message;
            }
        }

        action placeUnavailableMaterialOnHold {
            in item credential: PatronCredential;
            in item request: HoldRequest;
            out item queuedRequest: HoldRequest;
            out item message: NotificationMessage;

            first validatePatron;
            then assignQueuePosition;
            then reserveNextEligibleCopy;
            then sendHoldConfirmation;

            action validatePatron {
                in item credential;
                out item patron: PatronProfile;
            }

            action assignQueuePosition {
                in item request;
                out item queuedRequest;
            }

            action reserveNextEligibleCopy {
                in item queuedRequest;
            }

            action sendHoldConfirmation {
                in item queuedRequest;
                out item message;
            }
        }
    }

    requirement def IntegratedLibrarySystemRequirement {
        subject ils: IntegratedLibrarySystem;
        require constraint {
            ils.targetAvailabilityPercent >= 99.5
        }
    }

    requirement catalogDiscoveryRequirement : IntegratedLibrarySystemRequirement {
        doc /* The system shall provide patrons and staff with searchable discovery of cataloged physical and digital materials by title, creator, keyword, subject, and ISBN. */
        require constraint {
            ils.catalog.indexedTitles > 0 and ils.catalog.indexedItems > 0
        }
    }

    requirement patronAccessRequirement : IntegratedLibrarySystemRequirement {
        doc /* The system shall authenticate patrons before allowing account-specific actions including checkout, renewal, hold placement, fee payment, and review of active loans. */
        require constraint {
            ils.patronAccounts.maxActiveLoansPerPatron > 0
        }
    }

    requirement circulationRequirement : IntegratedLibrarySystemRequirement {
        doc /* The system shall maintain accurate lifecycle status for each library material as it moves through availability, checkout, hold, transfer, loss, and retirement states. */
        require constraint {
            ils.circulation.maximumRenewals >= 0
        }
    }

    requirement holdManagementRequirement : IntegratedLibrarySystemRequirement {
        doc /* The system shall support hold queues for unavailable materials and notify patrons when an eligible copy is ready for pickup. */
        require constraint {
            ils.holds.holdPickupWindow.days >= 1
        }
    }

    requirement feeManagementRequirement : IntegratedLibrarySystemRequirement {
        doc /* The system shall assess, track, collect, waive, and dispute monetary obligations associated with overdue, lost, or damaged materials. */
        require constraint {
            ils.finance.paymentsProcessedToday >= 0
        }
    }

    requirement notificationRequirement : IntegratedLibrarySystemRequirement {
        doc /* The system shall issue due date, overdue, hold availability, checkout confirmation, and account status notifications through configured communication channels. */
        require constraint {
            ils.notifications.deliverySuccessPercent >= 95.0
        }
    }

    requirement digitalServiceRequirement : IntegratedLibrarySystemRequirement {
        doc /* The system shall expose online patron services for catalog search, authentication, hold placement, loan review, renewal, and payment. */
        require constraint {
            ils.digitalAccess.webAvailabilityPercent >= 99.0
        }
    }

    satisfy catalogDiscoveryRequirement by IntegratedLibrarySystem::catalog;
    satisfy patronAccessRequirement by IntegratedLibrarySystem::patronAccounts;
    satisfy circulationRequirement by IntegratedLibrarySystem::circulation;
    satisfy holdManagementRequirement by IntegratedLibrarySystem::holds;
    satisfy feeManagementRequirement by IntegratedLibrarySystem::finance;
    satisfy notificationRequirement by IntegratedLibrarySystem::notifications;
    satisfy digitalServiceRequirement by IntegratedLibrarySystem::digitalAccess;

    part librarySystem: IntegratedLibrarySystem {
        attribute participatingBranches = 24;
        attribute catalogRecordCount = 250000;
        attribute physicalItemCount = 840000;
        attribute digitalItemCount = 125000;
    }
}