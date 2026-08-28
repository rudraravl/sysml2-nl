package IntegratedLibrarySystem {
    private import ScalarValues::*;
    private import Time::DateTime;

    unit usd;
    value type FineAmount : Real [usd];

    package DataTypes {
        enum def BookStatus { Available; CheckedOut; Lost; }
        enum def AccountStatus { GoodStanding; Suspended; }
        enum def NotificationType { DueReminder; OverdueAlert; ReservationReady; }

        item def Book {
            attribute isbn : String;
            attribute title : String;
            attribute author : String;
            attribute bookSubject : String;
            attribute location : String;
            attribute condition : String;
            attribute status : BookStatus;
        }

        item def Patron {
            attribute patronId : String;
            attribute name : String;
            attribute accountStatus : AccountStatus;
            attribute outstandingFines : FineAmount;
            attribute borrowedCount : Integer;
            attribute maxBorrowLimit : Integer;
        }

        item def Loan {
            ref part borrowedBook : Book;
            ref part borrowingPatron : Patron;
            attribute checkoutDate : DateTime;
            attribute dueDate : DateTime;
            attribute returnDate : DateTime;
            attribute fineAmount : FineAmount;
        }

        item def Notification {
            attribute type : NotificationType;
            attribute notificationMessage : String;
            ref part targetPatron : Patron;
        }

        item def SearchQuery {
            attribute criteria : String;
        }

        item def CheckoutRequest {
            ref part patron : Patron;
            ref part book : Book;
        }

        item def ReturnRequest {
            ref part loan : Loan;
        }

        item def ValidationResult {
            attribute isValid : Boolean;
            ref part patron : Patron;
        }
    }

    package Interfaces {
        public import DataTypes::*;

        port def CatalogPort {
            in query : SearchQuery;
            out bookInfo : Book;
            in updateStatus : Book;
        }

        port def PatronPort {
            in validate : Patron;
            out validation : ValidationResult;
            in updateFines : Patron;
        }

        port def CirculationPort {
            in checkoutReq : CheckoutRequest;
            in returnReq : ReturnRequest;
            out loanRecord : Loan;
            out fineAmount : FineAmount;
        }

        port def NotificationPort {
            in notify : Notification;
        }

        interface def CatalogInterface {
            end catalog : CatalogPort;
            end circulation : ~CatalogPort;
        }

        interface def PatronInterface {
            end patron : PatronPort;
            end circulation : ~PatronPort;
        }

        interface def NotificationInterface {
            end notification : NotificationPort;
            end circulation : ~NotificationPort;
        }
    }

    package Components {
        public import DataTypes::*;
        public import Interfaces::*;

        part def CatalogManagement {
            port catalogPort : CatalogPort;
            attribute books : Book[*];

            perform action catalogBehavior {
                in query : SearchQuery;
                out result : Book;
                in update : Book;

                action searchDatabase {
                    in q : SearchQuery;
                    out b : Book;
                }
                action updateRecord {
                    in b : Book;
                }
            }
        }

        part def PatronManagement {
            port patronPort : PatronPort;
            attribute patrons : Patron[*];

            perform action patronBehavior {
                in patron : Patron;
                out validation : ValidationResult;
                in update : Patron;

                action checkAccount {
                    in p : Patron;
                    out v : ValidationResult;
                }
                action applyFineUpdate {
                    in p : Patron;
                }
            }
        }

        part def CirculationManagement {
            port circulationPort : CirculationPort;
            port catalogInterface : ~CatalogPort;
            port patronInterface : ~PatronPort;
            port notificationInterface : ~NotificationPort;

            attribute activeLoans : Loan[*];

            perform state machine CirculationBehavior {
                state Idle;
                accept checkoutReq : CheckoutRequest via circulationPort.checkoutReq
                then ProcessingCheckout;

                state ProcessingCheckout;
                accept valRes : ValidationResult via patronInterface.validation
                then CheckingBook;

                state CheckingBook;
                accept bookRes : Book via catalogInterface.bookInfo
                then Idle;
            }

            perform state machine OverdueScanner {
                state Scanning;
                then Scanning;
            }
        }

        part def NotificationSystem {
            port notificationPort : NotificationPort;

            perform state machine NotificationBehavior {
                state Idle;
                accept notify : Notification via notificationPort.notify
                then Idle;
            }
        }
    }

    package SystemArchitecture {
        public import Components::*;
        public import Interfaces::*;

        part ilsSystem {
            part catalog : CatalogManagement;
            part patron : PatronManagement;
            part circulation : CirculationManagement;
            part notifications : NotificationSystem;

            interface catalogConn : CatalogInterface connect circulation.catalogInterface to catalog.catalogPort {
                flow query from catalogConn.circulation.query to catalogConn.catalog.query;
                flow bookInfo from catalogConn.catalog.bookInfo to catalogConn.circulation.bookInfo;
                flow updateStatus from catalogConn.circulation.updateStatus to catalogConn.catalog.updateStatus;
            }

            interface patronConn : PatronInterface connect circulation.patronInterface to patron.patronPort {
                flow validate from patronConn.circulation.validate to patronConn.patron.validate;
                flow validation from patronConn.patron.validation to patronConn.circulation.validation;
                flow updateFines from patronConn.circulation.updateFines to patronConn.patron.updateFines;
            }

            interface notifConn : NotificationInterface connect circulation.notificationInterface to notifications.notificationPort {
                flow notify from notifConn.circulation.notify to notifConn.notification.notify;
            }
        }
    }

    package Requirements {
        requirement def Req_Catalog {
            doc /* Track every book in the collection, including title, author, ISBN, location, and condition. */
            attribute id : String = "REQ-001";
        }
        requirement def Req_Patron {
            doc /* Manage patron accounts, tracking borrowing history, limits, and fines. */
            attribute id : String = "REQ-002";
        }
        requirement def Req_Circulation {
            doc /* Handle circulation: validate patron, check availability, create loan, update records. */
            attribute id : String = "REQ-003";
        }
        requirement def Req_Notification {
            doc /* Automated notifications for due dates, overdue items, and reservations. */
            attribute id : String = "REQ-004";
        }
        requirement def Req_OverdueScan {
            doc /* Continuously scan active loans to identify overdue items, trigger alerts, and apply fines. */
            attribute id : String = "REQ-005";
        }
    }
}
