package ISBNBookIdentificationSystem {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Value Types ----
    value def YearOfPublication :> Integer {
        constraint { self >= 1450 and self <= 2100 }
    }

    value def EditionNumber :> Integer {
        constraint { self >= 1 }
    }

    value def ISBN13 :> String {
        constraint { self->size() == 13 }
        constraint { self.matches("[0-9]{13}") }
    }

    value def CheckDigit :> Integer {
        constraint { self >= 0 and self <= 9 }
    }

    // ---- Item Types ----
    item def BookRecord {
        attribute isbn : ISBN13;
        attribute title : String;
        attribute author : String;
        attribute publisher : String;
        attribute publicationYear : YearOfPublication;
        attribute edition : EditionNumber;
    }

    item def ScanResult {
        attribute isbn : ISBN13;
        attribute captureMethod : String; // "optical" or "manual"
        attribute timestamp : String;
    }

    item def ValidationOutcome {
        attribute isbn : ISBN13;
        attribute isValid : Boolean;
        attribute message : String;
    }

    item def LocalQuery {
        attribute isbn : ISBN13;
    }

    item def LocalResponse {
        attribute isbn : ISBN13;
        attribute found : Boolean;
        attribute record : BookRecord[0..1];
    }

    item def ExternalQuery {
        attribute isbn : ISBN13;
        attribute sourceName : String;
    }

    item def ExternalResponse {
        attribute isbn : ISBN13;
        attribute found : Boolean;
        attribute record : BookRecord[0..1];
        attribute sourceName : String;
    }

    item def DisplayMessage {
        attribute status : String;
        attribute record : BookRecord[0..1];
        attribute message : String;
    }

    // ---- Port Definitions ----
    port def ScanPort {
        out item scanResult : ScanResult;
    }

    port def ValidationPort {
        in item scanResult : ScanResult;
        out item outcome : ValidationOutcome;
    }

    port def LocalDBPort {
        in item query : LocalQuery;
        out item response : LocalResponse;
    }

    port def ExternalGatewayPort {
        in item query : ExternalQuery;
        out item response : ExternalResponse;
    }

    port def DisplayPort {
        in item message : DisplayMessage;
    }

    // ---- ISBN Scanner ----
    part def ISBNScanner {
        attribute captureMode : String default "optical"; // "optical" or "manual"
        port scanOut : ScanPort;

        action def CaptureISBN {
            in rawInput : String;
            out result : ScanResult;
        }

        perform action capture : CaptureISBN {
            in rawInput;
            out result;
        }
    }

    // ---- ISBN Validator ----
    part def ISBNValidator {
        port scanIn : ScanPort;
        port validationOut : ValidationPort;

        action def ValidateISBN {
            in scan : ScanResult;
            out outcome : ValidationOutcome;

            private attribute digits : Integer[13];
            private attribute sum : Integer;
            private attribute computedCheck : Integer;
            private attribute i : Integer;
            private attribute weight : Integer;
            private attribute d : Integer;

            // Compute modulo 10 check digit for ISBN-13
            assign sum := 0;
            assign i := 0;
            while i < 12 {
                assign d := Integer::parse(scan.isbn.substring(i + 1, i + 1));
                assign weight := if (i mod 2 == 0) then 1 else 3;
                assign sum := sum + d * weight;
                assign i := i + 1;
            }
            assign computedCheck := (10 - (sum mod 10)) mod 10;
            assign outcome.isValid := (computedCheck == Integer::parse(scan.isbn.substring(13, 13)));
            assign outcome.isbn := scan.isbn;
            assign outcome.message := if outcome.isValid then "Valid ISBN" else "Invalid check digit";
        }

        perform action validate : ValidateISBN {
            in scan = scanIn.scanResult;
            out outcome = validationOut.outcome;
        }
    }

    // ---- Central Database ----
    part def CentralDatabase {
        port dbPort : LocalDBPort;
        attribute records : BookRecord[*] := {};

        action def LookupLocal {
            in query : LocalQuery;
            out response : LocalResponse;

            attribute foundRecord : BookRecord[0..1];
            assign foundRecord := records->select(r | r.isbn == query.isbn)->first();
            assign response.isbn := query.isbn;
            assign response.found := foundRecord->notEmpty();
            assign response.record := foundRecord;
        }

        action def StoreRecord {
            in newRecord : BookRecord;
            then {
                records := records->excluding(records->select(r | r.isbn == newRecord.isbn));
                records := records->including(newRecord);
            }
        }

        perform action lookup : LookupLocal {
            in query = dbPort.query;
            out response = dbPort.response;
        }
    }

    // ---- Network Gateway ----
    part def NetworkGateway {
        port gatewayPort : ExternalGatewayPort;
        attribute externalSources : String[*] := {"ISBN Agency", "Library of Congress", "WorldCat"};

        action def QueryExternalSource {
            in query : ExternalQuery;
            out response : ExternalResponse;

            // Simulate external lookup
            assign response.isbn := query.isbn;
            assign response.sourceName := query.sourceName;
            assign response.found := true;
            assign response.record := BookRecord {
                isbn := query.isbn,
                title := "Retrieved from " + query.sourceName,
                author := "Unknown Author",
                publisher := "External Publisher",
                publicationYear := 2020,
                edition := 1
            };
        }

        perform action queryExternal : QueryExternalSource {
            in query = gatewayPort.query;
            out response = gatewayPort.response;
        }
    }

    // ---- User Interface ----
    part def UserInterface {
        port displayIn : DisplayPort;

        action def RenderDisplay {
            in message : DisplayMessage;

            attribute displayText : String;
            assign displayText := if message.record->notEmpty()
                then "Title: " + message.record.title +
                     "\nAuthor: " + message.record.author +
                     "\nPublisher: " + message.record.publisher +
                     "\nYear: " + message.record.publicationYear.toString() +
                     "\nEdition: " + message.record.edition.toString() +
                     "\nISBN: " + message.record.isbn
                else message.message;
        }

        perform action render : RenderDisplay {
            in message = displayIn.message;
        }
    }

    // ---- System Controller ----
    part def SystemController {
        port scannerPort : ScanPort;
        port validatorPort : ValidationPort;
        port dbPort : LocalDBPort;
        port gatewayPort : ExternalGatewayPort;
        port uiPort : DisplayPort;

        attribute currentISBN : ISBN13;
        attribute currentRecord : BookRecord[0..1];

        state machine controllerStateMachine {
            entry; then idle;

            state idle {
                entry {
                    currentISBN := "";
                    currentRecord := {};
                }
            }

            state scanning {
                entry {
                    // Wait for scan result from scanner
                }
            }

            state validating {
                entry {
                    // Trigger validation
                }
            }

            state queryingLocal {
                entry {
                    // Query local database
                }
            }

            state queryingExternal {
                entry {
                    // Query external sources
                }
            }

            state displaying {
                entry {
                    // Send display message
                }
            }

            transition idle_to_scanning
                first idle then scanning
                when scannerPort.scanResult->notEmpty();

            transition scanning_to_validating
                first scanning then validating
                when validatorPort.outcome->notEmpty();

            transition validating_to_queryingLocal
                first validating then queryingLocal
                when validatorPort.outcome.isValid == true;

            transition validating_to_idle_invalid
                first validating then idle
                when validatorPort.outcome.isValid == false;

            transition queryingLocal_to_displaying_found
                first queryingLocal then displaying
                when dbPort.response.found == true;

            transition queryingLocal_to_queryingExternal
                first queryingLocal then queryingExternal
                when dbPort.response.found == false;

            transition queryingExternal_to_displaying_found
                first queryingExternal then displaying
                when gatewayPort.response.found == true;

            transition queryingExternal_to_idle_notfound
                first queryingExternal then idle
                when gatewayPort.response.found == false;

            transition displaying_to_idle
                first displaying then idle
                done;
        }
    }

    // ---- Top-level System ----
    part def ISBNBookIdentificationSystem {
        part scanner : ISBNScanner {
            port scanOut : ScanPort;
        }

        part validator : ISBNValidator {
            port scanIn : ScanPort;
            port validationOut : ValidationPort;
        }

        part database : CentralDatabase {
            port dbPort : LocalDBPort;
        }

        part gateway : NetworkGateway {
            port gatewayPort : ExternalGatewayPort;
        }

        part ui : UserInterface {
            port displayIn : DisplayPort;
        }

        part controller : SystemController {
            port scannerPort : ScanPort;
            port validatorPort : ValidationPort;
            port dbPort : LocalDBPort;
            port gatewayPort : ExternalGatewayPort;
            port uiPort : DisplayPort;
        }

        connect scanner.scanOut to validator.scanIn;
        connect validator.validationOut to controller.validatorPort;
        connect controller.dbPort to database.dbPort;
        connect controller.gatewayPort to gateway.gatewayPort;
        connect controller.uiPort to ui.displayIn;
    }

    // ---- Requirements ----
    requirement def ISBNRecognitionRequirement {
        subject : ISBNBookIdentificationSystem;
        objective {
            doc "The system shall recognize and capture a 13-digit ISBN from a physical book using either an optical barcode reader or manual input."
        }
    }

    requirement def ISBNValidationRequirement {
        subject : ISBNBookIdentificationSystem;
        objective {
            doc "The system shall validate the captured ISBN by verifying its format and computing the modulo 10 check digit."
        }
        constraint {
            doc "The validator shall reject ISBNs whose computed check digit does not match the 13th digit."
        }
    }

    requirement def LocalDatabaseLookupRequirement {
        subject : ISBNBookIdentificationSystem;
        objective {
            doc "The system shall query a local Central Database for book records matching a valid ISBN before querying external sources."
        }
    }

    requirement def ExternalLookupRequirement {
        subject : ISBNBookIdentificationSystem;
        objective {
            doc "If the book record is not found locally, the system shall query external authoritative sources via the Network Gateway."
        }
    }

    requirement def DatabaseUpdateRequirement {
        subject : ISBNBookIdentificationSystem;
        objective {
            doc "When a record is retrieved from an external source, the system shall store it in the local Central Database for future fast access."
        }
    }

    requirement def DisplayRequirement {
        subject : ISBNBookIdentificationSystem;
        objective {
            doc "The system shall display the retrieved book information—including title, author, publisher, publication year, and edition—in a clear and structured format."
        }
    }

    requirement def StateBehaviorRequirement {
        subject : ISBNBookIdentificationSystem;
        objective {
            doc "The system shall operate through the states: idle, scanning, validating, querying (local then external), and displaying, returning to idle after each lookup."
        }
    }

    requirement identificationReq : ISBNRecognitionRequirement;
    requirement validationReq : ISBNValidationRequirement;
    requirement localLookupReq : LocalDatabaseLookupRequirement;
    requirement externalLookupReq : ExternalLookupRequirement;
    requirement dbUpdateReq : DatabaseUpdateRequirement;
    requirement displayReq : DisplayRequirement;
    requirement stateBehaviorReq : StateBehaviorRequirement;

    satisfaction satisfy identificationReq by scanner;
    satisfaction satisfy validationReq by validator;
    satisfaction satisfy localLookupReq by database;
    satisfaction satisfy externalLookupReq by gateway;
    satisfaction satisfy dbUpdateReq by database;
    satisfaction satisfy displayReq by ui;
    satisfaction satisfy stateBehaviorReq by controller;
}
