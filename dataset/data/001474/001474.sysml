package IntegratedLibrarySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ISBN;
    attribute def PatronID;
    attribute def BookTitle;
    attribute def AuthorName;
    attribute def CallNumber;
    attribute def FineAmount;
    attribute def LoanPeriod;
    
    item def Book {
        attribute isbn : ISBN;
        attribute title : BookTitle;
        attribute author : AuthorName;
        attribute callNumber : CallNumber;
        attribute isAvailable : Boolean;
        attribute condition : BookCondition;
        attribute location : String;
    }
    
    item def PatronRecord {
        attribute patronId : PatronID;
        attribute name : String;
        attribute isActive : Boolean;
        attribute borrowLimit : Integer;
        attribute currentBorrowCount : Integer;
        attribute outstandingFines : FineAmount;
    }
    
    item def LoanTransaction {
        attribute bookIsbn : ISBN;
        attribute patronId : PatronID;
        attribute checkoutDate : Real;
        attribute dueDate : Real;
        attribute returnDate : Real;
        attribute fineAccrued : FineAmount;
    }
    
    item def SearchQuery {
        attribute searchTerm : String;
        attribute searchType : SearchType;
    }
    
    item def SearchResults {
        attribute books : Book[*];
        attribute resultCount : Integer;
    }
    
    item def CheckoutRequest {
        attribute patron : PatronID;
        attribute book : ISBN;
    }
    
    item def CheckoutResponse {
        attribute success : Boolean;
        attribute dueDate : Real;
        attribute responseMessage : String;
    }
    
    item def ReturnRequest {
        attribute book : ISBN;
        attribute patron : PatronID;
    }
    
    item def ReturnResponse {
        attribute success : Boolean;
        attribute fine : FineAmount;
        attribute responseMessage : String;
    }
    
    enum def BookCondition {
        enum excellent;
        enum good;
        enum fair;
        enum poor;
        enum damaged;
    }
    
    enum def SearchType {
        enum byTitle;
        enum byAuthor;
        enum byISBN;
        enum bySubject;
    }
    
    enum def LoanStatus {
        enum available;
        enum checkedOut;
        enum overdue;
        enum reserved;
        enum lost;
    }
    
    port def CatalogServicePort {
        in searchRequest : SearchQuery;
        out searchResponse : SearchResults;
        in addBookRequest : Book;
        out addBookResponse : Boolean;
    }
    
    port def CirculationServicePort {
        in checkoutReq : CheckoutRequest;
        out checkoutResp : CheckoutResponse;
        in returnReq : ReturnRequest;
        out returnResp : ReturnResponse;
    }
    
    port def PatronServicePort {
        in patronQuery : PatronID;
        out patronInfo : PatronRecord;
        in updatePatronRequest : PatronRecord;
        out updatePatronResponse : Boolean;
    }
    
    port def NotificationPort {
        out overdueNotice : String;
        out dueReminder : String;
        out availabilityAlert : String;
    }
    
    part def CatalogManagement {
        port catalogPort : CatalogServicePort;
        attribute catalogDatabase : Book[*];
        
        action def SearchCatalog {
            in query : SearchQuery;
            out results : SearchResults;
        }
        
        action def AddBookToCatalog {
            in newBook : Book;
            out success : Boolean;
        }
        
        action def UpdateBookStatus {
            in bookIsbn : ISBN;
            in available : Boolean;
            out updated : Boolean;
        }
        
        action def RemoveBook {
            in bookIsbn : ISBN;
            out removed : Boolean;
        }
    }
    
    part def CirculationManagement {
        port circulationPort : CirculationServicePort;
        attribute activeLoans : LoanTransaction[*];
        attribute loanHistory : LoanTransaction[*];
        attribute standardLoanPeriod : LoanPeriod;
        attribute fineRatePerDay : FineAmount;
        
        action def ProcessCheckout {
            in request : CheckoutRequest;
            out response : CheckoutResponse;
            
            first start;
            then action validatePatron {
                in patronId : PatronID;
                out isValid : Boolean;
                out canBorrow : Boolean;
            }
            then decide;
                if validatePatron.isValid and validatePatron.canBorrow then verifyBook;
                else rejectCheckout;
            
            action verifyBook {
                in bookIsbn : ISBN;
                out isAvailable : Boolean;
            }
            then decide;
                if verifyBook.isAvailable then createLoan;
                else rejectCheckout;
            
            action createLoan {
                in patronId : PatronID;
                in bookIsbn : ISBN;
                out loan : LoanTransaction;
            }
            then action updateInventory {
                in bookIsbn : ISBN;
            }
            then action confirmCheckout {
                out confirmation : CheckoutResponse;
            }
            then done;
            
            action rejectCheckout {
                out rejection : CheckoutResponse;
            }
            then done;
        }
        
        action def ProcessReturn {
            in request : ReturnRequest;
            out response : ReturnResponse;
            
            first start;
            then action findLoan {
                in bookIsbn : ISBN;
                in patronId : PatronID;
                out loan : LoanTransaction;
            }
            then action calculateFine {
                in loan : LoanTransaction;
                out fine : FineAmount;
            }
            then action updateLoanRecord {
                in loan : LoanTransaction;
                in fine : FineAmount;
            }
            then action markBookAvailable {
                in bookIsbn : ISBN;
            }
            then action generateResponse {
                in fine : FineAmount;
                out returnResponse : ReturnResponse;
            }
            then done;
        }
        
        action def CalculateOverdueFine {
            in dueDate : Real;
            in returnDate : Real;
            in ratePerDay : FineAmount;
            out totalFine : FineAmount;
        }
    }
    
    part def PatronManagement {
        port patronPort : PatronServicePort;
        attribute patronDatabase : PatronRecord[*];
        
        action def RegisterPatron {
            in patronInfo : PatronRecord;
            out success : Boolean;
        }
        
        action def ValidatePatron {
            in patronId : PatronID;
            out isValid : Boolean;
            out record : PatronRecord;
        }
        
        action def UpdatePatronRecord {
            in patronId : PatronID;
            in borrowCount : Integer;
            in fines : FineAmount;
            out updated : Boolean;
        }
        
        action def CheckBorrowingEligibility {
            in patronId : PatronID;
            out canBorrow : Boolean;
            out reason : String;
        }
    }
    
    part def NotificationSystem {
        port notificationPort : NotificationPort;
        
        action def SendOverdueNotice {
            in patronId : PatronID;
            in bookIsbn : ISBN;
            in daysOverdue : Integer;
            out sent : Boolean;
        }
        
        action def SendDueReminder {
            in patronId : PatronID;
            in bookIsbn : ISBN;
            in daysUntilDue : Integer;
            out sent : Boolean;
        }
        
        action def SendAvailabilityAlert {
            in patronId : PatronID;
            in bookIsbn : ISBN;
            out sent : Boolean;
        }
    }
    
    action def ManageLibraryOperations {
        doc /* 
            Primary function: Coordinate all library operations including catalog search,
            material checkout and return, patron management, and automated notifications
            to provide seamless access to library resources.
        */
        
        in patronRequest : PatronID;
        in operationType : String;
        out operationResult : Boolean;
        
        first start;
        then merge processRequest;
        
        action authenticatePatron {
            in patron : PatronID;
            out authenticated : Boolean;
            out patronData : PatronRecord;
        }
        
        then decide;
            if authenticatePatron.authenticated then routeOperation;
            else rejectOperation;
        
        action routeOperation {
            in opType : String;
        }
        
        then decide;
            if operationType == "search" then handleSearch;
            if operationType == "checkout" then handleCheckout;
            if operationType == "return" then handleReturn;
            else rejectOperation;
        
        action handleSearch {
            in query : SearchQuery;
            out results : SearchResults;
        }
        then processRequest;
        
        action handleCheckout {
            in checkoutReq : CheckoutRequest;
            out checkoutResp : CheckoutResponse;
        }
        then action updatePatronCheckout {
            in patron : PatronID;
        }
        then action scheduleReminder {
            in dueDate : Real;
        }
        then processRequest;
        
        action handleReturn {
            in returnReq : ReturnRequest;
            out returnResp : ReturnResponse;
        }
        then action updatePatronReturn {
            in patron : PatronID;
            in fine : FineAmount;
        }
        then decide;
            if handleReturn.returnResp.fine > 0.0 then notifyFine;
            else processRequest;
        
        action notifyFine {
            in patron : PatronID;
            in amount : FineAmount;
        }
        then processRequest;
        
        action rejectOperation {
            out rejection : String;
        }
        then done;
    }
    
    action def MonitorOverdueItems {
        out overdueCount : Integer;
        
        first start;
        then merge checkCycle;
        
        action retrieveActiveLoans {
            out loans : LoanTransaction[*];
        }
        
        then action identifyOverdueLoans {
            in loans : LoanTransaction[*];
            out overdueLoans : LoanTransaction[*];
        }
        
        then decide;
            if identifyOverdueLoans.overdueLoans->notEmpty() then processOverdue;
            else waitAndCheck;
        
        action processOverdue {
            in overdueLoans : LoanTransaction[*];
        }
        
        then action sendNotifications {
            in loans : LoanTransaction[*];
            out notificationsSent : Integer;
        }
        
        then action updateFines {
            in loans : LoanTransaction[*];
            out finesCalculated : FineAmount;
        }
        
        then waitAndCheck;
        
        action waitAndCheck;
        then checkCycle;
    }
    
    state def LibraryOperationStates {
        entry; then Idle;
        
        state Idle;
        state ProcessingRequest;
        state ValidatingPatron;
        state SearchingCatalog;
        state ProcessingCheckout;
        state ProcessingReturn;
        state UpdatingRecords;
        state SendingNotification;
        state Error;
        
        transition first Idle then ProcessingRequest;
        transition ProcessingRequest then ValidatingPatron;
        transition ValidatingPatron then SearchingCatalog;
        transition ValidatingPatron then ProcessingCheckout;
        transition ValidatingPatron then ProcessingReturn;
        transition ValidatingPatron then Error;
        transition SearchingCatalog then Idle;
        transition ProcessingCheckout then UpdatingRecords;
        transition ProcessingReturn then UpdatingRecords;
        transition UpdatingRecords then SendingNotification;
        transition SendingNotification then Idle;
        transition Error then Idle;
    }
    
    part integratedLibrarySystem : IntegratedLibrarySystem {
        doc /* 
            The Integrated Library System provides comprehensive management of library
            resources and patron services. Its primary function is to enable efficient
            discovery, circulation, and tracking of library materials while maintaining
            accurate patron records and automating routine notifications. The system
            coordinates catalog management, circulation workflows, patron authentication,
            and notification services to deliver a seamless library experience.
        */
        
        part catalog : CatalogManagement {
            perform action maintainCatalog;
        }
        
        part circulation : CirculationManagement {
            perform action manageCirculation;
        }
        
        part patrons : PatronManagement {
            perform action managePatrons;
        }
        
        part notifications : NotificationSystem {
            perform action deliverNotifications;
        }
        
        connection catalogToCirculation 
            connect catalog.catalogPort to circulation.circulationPort;
        
        connection circulationToPatrons 
            connect circulation.circulationPort to patrons.patronPort;
        
        connection circulationToNotifications 
            connect circulation.circulationPort to notifications.notificationPort;
        
        perform action primaryOperations : ManageLibraryOperations;
        perform action overdueMonitoring : MonitorOverdueItems;
    }
    
    requirement <'ILS-REQ-001'> systemAvailability {
        doc /* The library system shall maintain 99.5% uptime during operational hours. */
        
        require constraint {
            uptimePercentage >= 99.5
        }
    }
    
    requirement <'ILS-REQ-002'> transactionPerformance {
        doc /* Checkout and return transactions shall complete within 5 seconds. */
        
        require constraint {
            transactionTime <= 5.0
        }
    }
    
    requirement <'ILS-REQ-003'> catalogSearchPerformance {
        doc /* Catalog searches shall return results within 2 seconds for 95% of queries. */
        
        require constraint {
            searchResponseTime <= 2.0
        }
    }
    
    requirement <'ILS-REQ-004'> dataIntegrity {
        doc /* All catalog, circulation, and patron records shall maintain referential integrity. */
        
        require constraint {
            catalogIntegrity and circulationIntegrity and patronIntegrity
        }
    }
    
    requirement <'ILS-REQ-005'> concurrentUsers {
        doc /* The system shall support at least 1000 concurrent patron sessions. */
        
        require constraint {
            maxConcurrentSessions >= 1000
        }
    }
    
    requirement <'ILS-REQ-006'> notificationDelivery {
        doc /* Overdue and due-date notifications shall be delivered within 24 hours of trigger event. */
        
        require constraint {
            notificationDelay <= 24.0
        }
    }
    
    requirement primaryLibraryFunction {
        doc /* 
            The Integrated Library System shall provide comprehensive library resource
            management by enabling patrons to search the catalog, borrow and return materials,
            while maintaining accurate inventory, patron records, and delivering timely
            notifications for due dates and overdue items.
        */
        
        assume constraint validCatalog {
            catalogSize > 0
        }
        
        assume constraint registeredPatrons {
            patronCount > 0
        }
        
        require systemAvailability;
        require transactionPerformance;
        require catalogSearchPerformance;
        require dataIntegrity;
        require concurrentUsers;
        require notificationDelivery;
    }
    
    satisfy integratedLibrarySystem.primaryOperations by primaryLibraryFunction;
    satisfy integratedLibrarySystem.catalog by catalogSearchPerformance;
    satisfy integratedLibrarySystem.circulation by transactionPerformance;
    satisfy integratedLibrarySystem.notifications by notificationDelivery;
}
