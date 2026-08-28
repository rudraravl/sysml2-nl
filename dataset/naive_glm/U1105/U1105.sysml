package LibrarySystem {
    import ScalarValues::*;
    
    attribute def USD :> Real;
    
    enum def Condition { new; good; fair; poor; }
    
    item def Book {
        attribute isbn : String;
        attribute title : String;
        attribute author : String;
        attribute subject : String;
        attribute location : String;
        attribute condition : Condition;
        attribute isAvailable : Boolean;
    }
    
    item def Patron {
        attribute patronId : String;
        attribute name : String;
        attribute contact : String;
        attribute borrowLimit : Integer;
        attribute outstandingFines : USD;
        attribute isActive : Boolean;
        attribute isGoodStanding : Boolean;
    }
    
    item def Loan {
        attribute loanId : String;
        attribute bookIsbn : String;
        attribute patronId : String;
        attribute checkoutDate : String;
        attribute dueDate : String;
        attribute returnDate : String;
        attribute isOverdue : Boolean;
        attribute fine : USD;
    }
    
    item def CheckoutRequest {
        attribute patronId : String;
        attribute bookIsbn : String;
    }
    
    item def ReturnRequest {
        attribute bookIsbn : String;
    }
    
    item def Notification {
        attribute patronId : String;
        attribute message : String;
        attribute type : String;
    }
    
    item def FineUpdate {
        attribute patronId : String;
        attribute fine : USD;
    }
    
    item def OverdueScanTimer;
    item def ScanComplete;
    
    port def CatalogPort {
        in item checkAvailability : String;
        out item availabilityStatus : Boolean;
        in item updateAvailability : String;
        out item searchResults : Book[0..*];
    }
    
    port def PatronPort {
        in item verifyPatron : String;
        out item patronStatus : Boolean;
        in item updateFines : FineUpdate;
        in item registerPatron : Patron;
    }
    
    port def CirculationPort {
        in item checkoutReq : CheckoutRequest;
        in item returnReq : ReturnRequest;
        out item loanRecord : Loan;
    }
    
    port def NotificationPort {
        in item sendNotification : Notification;
    }
    
    part def CatalogManagement {
        port catalogPort : CatalogPort;
        attribute books : Book[0..*];
        
        action def SearchBooks {
            in criteria : String;
            out results : Book[0..*];
        }
    }
    
    part def PatronManagement {
        port patronPort : PatronPort;
        attribute patrons : Patron[0..*];
        
        action def RegisterPatron {
            in patron : Patron;
        }
    }
    
    part def CirculationManagement {
        port circulationPort : CirculationPort;
        port catalogPort : CatalogPort;
        port patronPort : PatronPort;
        port notificationPort : NotificationPort;
        attribute activeLoans : Loan[0..*];
        
        state machine CirculationBehavior {
            state Idle;
            state ProcessingCheckout;
            state ProcessingReturn;
            state ScanningOverdue;
            
            transition initial to Idle;
            transition from Idle to ProcessingCheckout accept CheckoutRequest;
            transition from ProcessingCheckout to Idle accept Loan;
            transition from Idle to ProcessingReturn accept ReturnRequest;
            transition from ProcessingReturn to Idle accept Loan;
            transition from Idle to ScanningOverdue accept OverdueScanTimer;
            transition from ScanningOverdue to Idle accept ScanComplete;
        }
        
        action def ProcessCheckout {
            in request : CheckoutRequest;
            out loan : Loan;
            
            first verifyPatron {
                out patronStatus : Boolean;
            }
            then checkBook {
                out bookStatus : Boolean;
            }
            then createLoan {
                in valid : Boolean;
                out loan : Loan;
            }
            then updateCatalog {
                in isbn : String;
            }
        }
        
        action def ProcessReturn {
            in request : ReturnRequest;
            out loan : Loan;
            
            first finalizeTransaction {
                out loan : Loan;
            }
            then calculateFines {
                in loan : Loan;
                out fine : USD;
            }
            then updateCatalog {
                in isbn : String;
            }
        }
    }
    
    part def NotificationSystem {
        port notificationPort : NotificationPort;
        
        action def SendNotification {
            in notification : Notification;
        }
    }
    
    part def IntegratedLibrarySystem {
        part catalog : CatalogManagement;
        part patrons : PatronManagement;
        part circulation : CirculationManagement;
        part notifications : NotificationSystem;
        
        connect circulation.catalogPort to catalog.catalogPort;
        connect circulation.patronPort to patrons.patronPort;
        connect circulation.notificationPort to notifications.notificationPort;
    }
    
    requirement def TrackBooks {
        doc :> 'The system shall track every book in the collection, including title, author, ISBN, physical location, and current condition.';
    }
    
    requirement def ManagePatrons {
        doc :> 'The system shall manage patron accounts, tracking borrowing history, limits, and outstanding fines.';
    }
    
    requirement def HandleCirculation {
        doc :> 'The system shall handle the circulation of materials, including checkout and return workflows.';
    }
    
    requirement def SendNotifications {
        doc :> 'The system shall proactively send reminders for due dates, overdue notices, and reservation alerts.';
    }
    
    requirement def ILSRequirements {
        requirement trackBooks : TrackBooks;
        requirement managePatrons : ManagePatrons;
        requirement handleCirculation : HandleCirculation;
        requirement sendNotifications : SendNotifications;
    }
}
