package ISBNBookIdentificationSystem {
    private import ScalarValues::*;

    item def ScanStartSignal;
    item def ISBNCapturedSignal;
    item def ISBNValidSignal;
    item def ISBNInvalidSignal;
    item def LocalRecordFoundSignal;
    item def LocalRecordNotFoundSignal;
    item def ExternalRecordFoundSignal;
    item def DisplayCompleteSignal;

    item def ISBN13 {
        attribute digits : ScalarValues::String;
    }

    item def BookRecord {
        ref isbn : ISBN13;
        attribute title : ScalarValues::String;
        attribute author : ScalarValues::String;
        attribute publisher : ScalarValues::String;
        attribute publicationYear : ScalarValues::Integer;
        attribute edition : ScalarValues::String;
    }

    item def ValidationResult {
        attribute isValid : ScalarValues::Boolean;
        ref isbn : ISBN13;
        attribute errorMessage : ScalarValues::String;
    }

    item def LookupRequest {
        ref isbn : ISBN13;
    }

    item def ExternalRequest {
        ref isbn : ISBN13;
    }

    item def UpdateCommand {
        ref record : BookRecord;
    }

    port def ISBNPort {
        in ref isbn : ISBN13;
    }

    port def LookupRequestPort {
        in ref request : LookupRequest;
    }

    port def ValidationPort {
        in ref result : ValidationResult;
    }

    port def ExternalRequestPort {
        in ref request : ExternalRequest;
    }

    port def UpdatePort {
        in ref update : UpdateCommand;
    }

    port def BookRecordPort {
        in ref record : BookRecord;
    }

    interface def ISBNInterface {
        end source : ~ISBNPort;
        end target : ISBNPort;
    }

    interface def LookupRequestInterface {
        end source : ~LookupRequestPort;
        end target : LookupRequestPort;
    }

    interface def ValidationInterface {
        end source : ~ValidationPort;
        end target : ValidationPort;
    }

    interface def ExternalRequestInterface {
        end source : ~ExternalRequestPort;
        end target : ExternalRequestPort;
    }

    interface def UpdateInterface {
        end source : ~UpdatePort;
        end target : UpdatePort;
    }

    interface def BookRecordInterface {
        end source : ~BookRecordPort;
        end target : BookRecordPort;
    }

    part def ISBNScanner {
        port isbnOut : ~ISBNPort {
            out ref :>> isbn;
        }
        perform action scan {
            out ref captured : ISBN13;
            language "Alf"
            /*
            * Capture a 13-digit ISBN from an optical barcode reader or manual entry.
            */
        }
        flow isbnFlow from scan.captured to isbnOut.isbn;
    }

    part def ISBNValidator {
        port isbnIn : ISBNPort {
            in ref :>> isbn;
        }
        port lookupOut : ~LookupRequestPort {
            out ref :>> request;
        }
        port invalidOut : ~ValidationPort {
            out ref :>> result;
        }
        flow isbnInFlow from isbnIn.isbn to validate.input;
        flow requestFlow from validate.request to lookupOut.request;
        flow invalidFlow from validate.result to invalidOut.result;
        perform action validate {
            in ref input : ISBN13;
            out ref result : ValidationResult;
            out ref request : LookupRequest;
            language "Alf"
            /*
            * Verify that input.digits has length 13 and that the modulo-10
            * check digit is correct. If valid, result.isValid = true,
            * result.isbn = input, and request.isbn = input.
            * If invalid, result.isValid = false and result.errorMessage describes the error.
            */
        }
    }

    part def CentralDatabase {
        port queryIn : LookupRequestPort {
            in ref :>> request;
        }
        port externalOut : ~ExternalRequestPort {
            out ref :>> request;
        }
        port updateIn : UpdatePort {
            in ref :>> update;
        }
        port recordOut : ~BookRecordPort {
            out ref :>> record;
        }
        ref localRecords : BookRecord[*];
        flow queryRequestFlow from queryIn.request to queryLocal.request;
        flow externalRequestFlow from queryLocal.externalReq to externalOut.request;
        flow updateFlow from updateIn.update to applyUpdate.update;
        flow localRecordFlow from queryLocal.foundRecord to recordOut.record;
        flow storedRecordFlow from applyUpdate.storedRecord to recordOut.record;
        perform action queryLocal {
            in ref request : LookupRequest;
            out ref foundRecord : BookRecord;
            out ref externalReq : ExternalRequest;
            language "Alf"
            /*
            * Search localRecords for request.isbn.
            * If found, output foundRecord and no externalReq.
            * If not found, output externalReq.isbn = request.isbn.
            */
        }
        perform action applyUpdate {
            in ref update : UpdateCommand;
            out ref storedRecord : BookRecord;
            language "Alf"
            /*
            * Insert or refresh localRecords with update.record.
            * Output storedRecord for display.
            */
        }
    }

    part def NetworkGateway {
        port externalIn : ExternalRequestPort {
            in ref :>> request;
        }
        port updateOut : ~UpdatePort {
            out ref :>> update;
        }
        flow externalRequestFlow from externalIn.request to fetchExternal.request;
        flow updateFlow from fetchExternal.update to updateOut.update;
        perform action fetchExternal {
            in ref request : ExternalRequest;
            out ref update : UpdateCommand;
            language "Alf"
            /*
            * Query an external authoritative ISBN agency database or library network.
            * If a matching record is found, create an update command containing the
            * complete BookRecord so the local database can be refreshed.
            */
        }
    }

    part def UserInterface {
        port recordIn : BookRecordPort {
            in ref :>> record;
        }
        port statusIn : ValidationPort {
            in ref :>> result;
        }
        flow displayFlow from recordIn.record to display.record;
        flow statusFlow from statusIn.result to notifyInvalid.result;
        perform action display {
            in ref record : BookRecord;
            language "Alf"
            /*
            * Render the title, author, publisher, publication year, and edition
            * in a clear, structured format.
            */
        }
        perform action notifyInvalid {
            in ref result : ValidationResult;
            language "Alf"
            /*
            * Display the validation error message returned by the validator.
            */
        }
    }

    state def ISBNLookupStateMachine {
        entry;
        then idle;

        state idle;
        transition idle_to_scanning
            first idle
            accept ScanStartSignal
            then scanning;

        state scanning;
        transition scanning_to_validating
            first scanning
            accept ISBNCapturedSignal
            then validating;

        state validating;
        transition validating_to_queryingLocal
            first validating
            accept ISBNValidSignal
            then queryingLocal;
        transition validating_to_idle
            first validating
            accept ISBNInvalidSignal
            then idle;

        state queryingLocal;
        transition queryingLocal_to_displaying
            first queryingLocal
            accept LocalRecordFoundSignal
            then displaying;
        transition queryingLocal_to_queryingExternal
            first queryingLocal
            accept LocalRecordNotFoundSignal
            then queryingExternal;

        state queryingExternal;
        transition queryingExternal_to_displaying
            first queryingExternal
            accept ExternalRecordFoundSignal
            then displaying;

        state displaying;
        transition displaying_to_idle
            first displaying
            accept DisplayCompleteSignal
            then idle;
    }

    part def ISBNBookIdentificationSystem {
        part scanner : ISBNScanner;
        part validator : ISBNValidator;
        part database : CentralDatabase;
        part gateway : NetworkGateway;
        part ui : UserInterface;
        state systemState : ISBNLookupStateMachine;

        connect scanner.isbnOut to validator.isbnIn;
        connect validator.lookupOut to database.queryIn;
        connect validator.invalidOut to ui.statusIn;
        connect database.externalOut to gateway.externalIn;
        connect gateway.updateOut to database.updateIn;
        connect database.recordOut to ui.recordIn;
    }

    requirement def ISBNIdentificationRequirement {
        doc /* The system shall recognize, validate, and retrieve detailed bibliographic information for published works using their 13-digit ISBN. */
    }

    requirement def ISBNValidationRequirement {
        doc /* The ISBN Validator shall verify the 13-digit ISBN using a modulo 10 check-digit algorithm. */
    }

    requirement def LocalFirstQueryRequirement {
        doc /* The system shall query the local Central Database first and query external sources only if the record is not found locally. */
    }

    requirement def ExternalUpdateRequirement {
        doc /* Records retrieved from external sources shall update the local Central Database. */
    }

    requirement def DisplayRequirement {
        doc /* The User Interface shall display retrieved book records in a clear, structured format. */
    }
}
