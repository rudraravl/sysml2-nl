package 'ISBN Book Identification System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def ISBN13Code {
        doc /* International Standard Book Number with 13 digits conforming to ISO 2108 standard. */
        attribute prefix : Integer[3];
        attribute registrationGroup : Integer[1..5];
        attribute registrant : Integer[1..7];
        attribute publication : Integer[1..6];
        attribute checkDigit : Integer;
    }
    
    attribute def BookRecord {
        attribute isbn : ISBN13Code;
        attribute title : String;
        attribute author : String;
        attribute publisher : String;
        attribute publicationYear : Integer;
        attribute edition : Integer;
        attribute bookLanguage : String;
    }
    
    attribute def ValidationStatus {
        attribute isValid : Boolean;
        attribute errorCode : Integer;
        attribute statusMessage : String;
    }
    
    attribute def QueryResult {
        attribute found : Boolean;
        attribute record : BookRecord;
        attribute timestamp : Real;
    }
    
    part def ISBNScanner {
        doc /* Optical or manual input device for capturing ISBN codes from physical books. */
        port scanOutput {
            out scannedISBN : ISBN13Code;
        }
    }
    
    part def ISBNValidator {
        doc /* Validates ISBN-13 format and check digit using modulo 10 algorithm. */
        port validationInput {
            in isbnToValidate : ISBN13Code;
        }
        port validationOutput {
            out status : ValidationStatus;
        }
    }
    
    part def CentralDatabase {
        doc /* Repository of registered ISBN records with associated bibliographic metadata. */
        attribute bookRecords : BookRecord[*];
        port queryPort {
            in queryISBN : ISBN13Code;
            out result : QueryResult;
        }
        port updatePort {
            in newRecord : BookRecord;
            out updateConfirmed : Boolean;
        }
    }
    
    part def UserInterface {
        doc /* Display and interaction system for presenting book information to users. */
        port displayInput {
            in bookData : BookRecord;
        }
        port userInput {
            out requestedISBN : ISBN13Code;
        }
    }
    
    part def NetworkGateway {
        doc /* Communication interface for external ISBN agency databases and library systems. */
        port externalQuery {
            in isbn : ISBN13Code;
            out externalRecord : BookRecord;
        }
    }
    
    action def ScanISBNCode {
        doc /* Capture ISBN-13 barcode or manual entry from physical book. */
        out capturedISBN : ISBN13Code;
    }
    
    action def ValidateISBNFormat {
        doc /* Verify ISBN-13 structure and calculate check digit validation. */
        in isbn : ISBN13Code;
        out validationStatus : ValidationStatus;
    }
    
    action def ComputeCheckDigit {
        doc /* Calculate ISBN-13 check digit using weighted sum modulo 10 algorithm. */
        in prefix : Integer[3];
        in registrationGroup : Integer[1..5];
        in registrant : Integer[1..7];
        in publication : Integer[1..6];
        out checkDigit : Integer;
    }
    
    action def QueryLocalDatabase {
        doc /* Search internal database for ISBN record. */
        in isbn : ISBN13Code;
        out result : QueryResult;
    }
    
    action def QueryExternalDatabase {
        doc /* Retrieve book metadata from external ISBN agency or library network. */
        in isbn : ISBN13Code;
        out externalResult : BookRecord;
        out success : Boolean;
    }
    
    action def UpdateDatabaseRecord {
        doc /* Store or update book record in central database. */
        in record : BookRecord;
        out updateSuccess : Boolean;
    }
    
    action def DisplayBookInformation {
        doc /* Present retrieved book metadata to user interface. */
        in bookData : BookRecord;
    }
    
    action def ProcessISBNLookup {
        doc /* Complete workflow for identifying and retrieving book information from ISBN code. */
        in inputISBN : ISBN13Code;
        out bookInformation : BookRecord;
        out operationSuccess : Boolean;
        
        first start;
        then action validate : ValidateISBNFormat {
            in isbn = inputISBN;
            out validationStatus;
        }
        then decide isValidISBN;
            if validate.validationStatus.isValid then queryLocal;
            else reportError;
        
        action queryLocal : QueryLocalDatabase {
            in isbn = inputISBN;
            out result;
        }
        then decide foundLocally;
            if queryLocal.result.found then displayLocalResult;
            else queryExternal;
        
        action queryExternal : QueryExternalDatabase {
            in isbn = inputISBN;
            out externalResult;
            out success;
        }
        then decide foundExternally;
            if queryExternal.success then updateLocal;
            else reportNotFound;
        
        action updateLocal : UpdateDatabaseRecord {
            in record = queryExternal.externalResult;
            out updateSuccess;
        }
        then displayExternalResult;
        
        action displayLocalResult : DisplayBookInformation {
            in bookData = queryLocal.result.record;
        }
        then assign bookInformation := queryLocal.result.record;
        then assign operationSuccess := true;
        then done;
        
        action displayExternalResult : DisplayBookInformation {
            in bookData = queryExternal.externalResult;
        }
        then assign bookInformation := queryExternal.externalResult;
        then assign operationSuccess := true;
        then done;
        
        action reportError {
            then assign operationSuccess := false;
            then done;
        }
        
        action reportNotFound {
            then assign operationSuccess := false;
            then done;
        }
    }
    
    part isbnIdentificationSystem : ISBNIdentificationSystem {
        doc /*
         * The ISBN Book Identification System provides automated recognition, validation,
         * and retrieval of bibliographic information for published works using their
         * International Standard Book Number (ISBN-13). The system's primary function is
         * to uniquely identify books and related publications by scanning or entering
         * their ISBN code, validating the code's integrity, querying comprehensive
         * databases of registered publications, and presenting complete metadata including
         * title, author, publisher, edition, and publication details to users for
         * cataloging, inventory management, sales transactions, and library operations.
         */
        
        part scanner : ISBNScanner {
            perform action scanOperation : ScanISBNCode;
        }
        
        part validator : ISBNValidator {
            perform action validationOperation : ValidateISBNFormat;
        }
        
        part database : CentralDatabase {
            perform action queryOperation : QueryLocalDatabase;
            perform action updateOperation : UpdateDatabaseRecord;
        }
        
        part userInterface : UserInterface {
            perform action displayOperation : DisplayBookInformation;
        }
        
        part networkGateway : NetworkGateway {
            perform action externalQueryOperation : QueryExternalDatabase;
        }
        
        connection scanToValidator connect scanner.scanOutput.scannedISBN to validator.validationInput.isbnToValidate;
        connection validatorToDatabase connect validator.validationOutput to database.queryPort;
        connection databaseToDisplay connect database.queryPort.result to userInterface.displayInput.bookData;
        connection networkToDatabase connect networkGateway.externalQuery.externalRecord to database.updatePort.newRecord;
        
        perform action primaryOperation : ProcessISBNLookup[*] ordered;
    }
    
    part def ISBNIdentificationSystem;
    
    state def SystemOperationalStates {
        doc /* Lifecycle states of the ISBN identification system. */
        
        initial state Idle;
        
        state Scanning {
            entry action {
                action initiateScanning : ScanISBNCode;
            }
        }
        
        state Validating {
            entry action {
                action performValidation : ValidateISBNFormat;
            }
        }
        
        state Querying {
            entry action {
                action searchDatabase : QueryLocalDatabase;
            }
        }
        
        state RetrievingExternal {
            entry action {
                action fetchExternal : QueryExternalDatabase;
            }
        }
        
        state Displaying {
            entry action {
                action showResults : DisplayBookInformation;
            }
        }
        
        state Error;
        
        transition Idle -> Scanning;
        transition Scanning -> Validating;
        transition Validating -> Querying;
        transition Validating -> Error;
        transition Querying -> Displaying;
        transition Querying -> RetrievingExternal;
        transition RetrievingExternal -> Displaying;
        transition RetrievingExternal -> Error;
        transition Displaying -> Idle;
        transition Error -> Idle;
    }
    
    requirement <'ISBN-SYS-REQ-001'> uniqueIdentificationRequirement {
        doc /*
         * The system shall uniquely identify each published book edition using its
         * ISBN-13 code according to ISO 2108 standard, ensuring no two distinct
         * publications share the same identifier.
         */
        subject isbnIdentificationSystem;
        require constraint {
            doc /* Each ISBN-13 in the database must be unique and properly formatted. */
        }
    }
    
    requirement <'ISBN-SYS-REQ-002'> validationAccuracyRequirement {
        doc /*
         * The system shall validate ISBN-13 codes with 100% accuracy using the
         * modulo 10 weighted check digit algorithm, rejecting malformed or
         * invalid codes before database queries.
         */
        subject isbnIdentificationSystem.validator;
        require constraint {
            doc /* Check digit calculation must match ISBN-13 specification exactly. */
        }
    }
    
    requirement <'ISBN-SYS-REQ-003'> databaseQueryRequirement {
        doc /*
         * The system shall query the central database for book records matching
         * the validated ISBN code and return complete bibliographic metadata
         * within 2 seconds for 95% of queries.
         */
        subject isbnIdentificationSystem.database;
        require constraint {
            doc /* Query response time shall not exceed 2 seconds under normal load. */
        }
    }
    
    requirement <'ISBN-SYS-REQ-004'> externalIntegrationRequirement {
        doc /*
         * The system shall interface with external ISBN agency databases and
         * library networks to retrieve book information not found in the local
         * database, updating local records upon successful retrieval.
         */
        subject isbnIdentificationSystem.networkGateway;
        require constraint {
            doc /* External queries must complete within 10 seconds or timeout gracefully. */
        }
    }
    
    requirement <'ISBN-SYS-REQ-005'> dataIntegrityRequirement {
        doc /*
         * The system shall maintain data integrity by preventing duplicate ISBN
         * entries, validating all metadata fields, and logging all database
         * modifications with timestamps and user attribution.
         */
        subject isbnIdentificationSystem.database;
        require constraint {
            doc /* All database transactions must be atomic and logged. */
        }
    }
    
    requirement <'ISBN-SYS-REQ-006'> userInterfaceRequirement {
        doc /*
         * The system shall present retrieved book information in a clear,
         * structured format displaying title, author, publisher, publication
         * year, edition, and language to support user decision-making.
         */
        subject isbnIdentificationSystem.userInterface;
        require constraint {
            doc /* All mandatory metadata fields must be displayed when available. */
        }
    }
    
    requirement systemMissionRequirement {
        doc /*
         * The ISBN Book Identification System shall provide reliable, accurate,
         * and efficient identification of published works through ISBN-13 codes,
         * supporting library cataloging, retail operations, inventory management,
         * and bibliographic research with comprehensive metadata retrieval from
         * local and external authoritative sources.
         */
        
        require uniqueIdentificationRequirement;
        require validationAccuracyRequirement;
        require databaseQueryRequirement;
        require externalIntegrationRequirement;
        require dataIntegrityRequirement;
        require userInterfaceRequirement;
    }
}
