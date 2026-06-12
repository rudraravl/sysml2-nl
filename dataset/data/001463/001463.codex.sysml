package ISBNBasedBookInformationSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ISBN13 {
        attribute prefix : String;
        attribute registrationGroup : String;
        attribute registrant : String;
        attribute publication : String;
        attribute checkDigit : Integer;
    }

    attribute def Confidence {
        attribute value : Real;
    }

    attribute def Millisecond {
        attribute value : Real;
        unit ms;
    }

    item def ISBNInput {
        attribute rawText : String;
        attribute receivedAt : String;
    }

    item def ValidatedISBN {
        attribute isbn : ISBN13;
        attribute normalizedText : String;
        attribute validationConfidence : Confidence;
    }

    item def BookMetadata {
        attribute isbn : ISBN13;
        attribute title : String;
        attribute subtitle : String;
        attribute authors : String;
        attribute publisher : String;
        attribute publicationYear : Integer;
        attribute languageCode : String;
        attribute format : String;
    }

    item def LookupRequest {
        attribute isbn : ISBN13;
        attribute timeout : Millisecond;
    }

    item def LookupResponse {
        attribute found : Boolean;
        attribute metadata : BookMetadata;
        attribute responseTime : Millisecond;
    }

    item def UserMessage {
        attribute text : String;
        attribute severity : String;
    }

    port def ISBNTextPort {
        in item isbnInput : ISBNInput;
    }

    port def ValidationPort {
        in item isbnInput : ISBNInput;
        out item validatedISBN : ValidatedISBN;
        out item rejectionMessage : UserMessage;
    }

    port def CatalogLookupPort {
        out item lookupRequest : LookupRequest;
        in item lookupResponse : LookupResponse;
    }

    port def MetadataOutputPort {
        out item metadata : BookMetadata;
        out item message : UserMessage;
    }

    part def ISBNCaptureInterface {
        port textEntry : ISBNTextPort;
        attribute maxInputLength : Integer = 32;
    }

    part def ISBNValidator {
        port validation : ValidationPort;
        attribute acceptedPrefix : String = "978,979";
        attribute requiredDigitCount : Integer = 13;

        action normalizeISBN {
            in item input : ISBNInput;
            out item normalized : ISBNInput;
        }

        action computeCheckDigit {
            in item normalized : ISBNInput;
            out attribute computedDigit : Integer;
        }

        action validateISBN13 {
            in item normalized : ISBNInput;
            out item validISBN : ValidatedISBN;
            out item failure : UserMessage;
        }
    }

    part def CatalogGateway {
        port catalog : CatalogLookupPort;
        attribute primaryCatalogName : String = "Authoritative Book Catalog";
        attribute lookupTimeout : Millisecond = 2500 [ms];

        action requestMetadata {
            in item request : LookupRequest;
            out item response : LookupResponse;
        }
    }

    part def BookDescriptionComposer {
        port output : MetadataOutputPort;
        attribute summaryTemplate : String = "The ISBN identifies a book and retrieves its bibliographic description.";

        action composeHighLevelDescription {
            in item metadata : BookMetadata;
            out item message : UserMessage;
        }
    }

    part def ISBNBasedBookSystem {
        part capture : ISBNCaptureInterface;
        part validator : ISBNValidator;
        part catalogGateway : CatalogGateway;
        part composer : BookDescriptionComposer;

        port userISBN : ISBNTextPort = capture.textEntry;
        port bookDescription : MetadataOutputPort = composer.output;

        connect capture.textEntry to validator.validation;
        connect validator.validation to catalogGateway.catalog;
        connect catalogGateway.catalog to composer.output;

        attribute maximumLookupLatency : Millisecond = 3000 [ms];
        attribute minimumValidationConfidence : Confidence = 0.99;

        state def ProcessingState {
            state idle;
            state receivingISBN;
            state validatingISBN;
            state rejectingISBN;
            state requestingMetadata;
            state composingDescription;
            state presentingResult;
            state catalogUnavailable;

            transition first idle;
            transition idle_to_receiving
                first idle
                then receivingISBN
                accept ISBNInput;

            transition receiving_to_validating
                first receivingISBN
                then validatingISBN;

            transition validating_to_rejecting
                first validatingISBN
                then rejectingISBN
                if validationConfidence.value < 0.99;

            transition validating_to_lookup
                first validatingISBN
                then requestingMetadata
                if validationConfidence.value >= 0.99;

            transition lookup_to_composing
                first requestingMetadata
                then composingDescription
                if found == true;

            transition lookup_to_unavailable
                first requestingMetadata
                then catalogUnavailable
                if found == false;

            transition composing_to_presenting
                first composingDescription
                then presentingResult;

            transition presenting_to_idle
                first presentingResult
                then idle;

            transition rejecting_to_idle
                first rejectingISBN
                then idle;

            transition unavailable_to_idle
                first catalogUnavailable
                then idle;
        }

        action identifyBookByISBN {
            in item enteredISBN : ISBNInput;
            out item metadata : BookMetadata;
            out item message : UserMessage;

            action normalize : validator.normalizeISBN;
            action validate : validator.validateISBN13;
            action lookup : catalogGateway.requestMetadata;
            action compose : composer.composeHighLevelDescription;

            flow enteredISBN to normalize.input;
            flow normalize.normalized to validate.normalized;
            flow validate.validISBN to lookup.request;
            flow lookup.response.metadata to compose.metadata;
            flow lookup.response.metadata to metadata;
            flow compose.message to message;
        }
    }

    requirement def ValidISBNRequirement {
        subject system : ISBNBasedBookSystem;
        doc /* The system shall accept an ISBN-13 input, normalize separators, verify the prefix and check digit, and reject invalid values before catalog lookup. */
    }

    requirement def PrimaryFunctionRequirement {
        subject system : ISBNBasedBookSystem;
        doc /* The system shall use a valid ISBN as a unique book identifier to retrieve bibliographic metadata and present a high-level description of the identified book. */
    }

    requirement def LookupLatencyRequirement {
        subject system : ISBNBasedBookSystem;
        attribute maxLatency : Millisecond = 3000 [ms];
        doc /* The system shall complete validation, catalog lookup, and description composition within 3000 ms for a valid ISBN under nominal catalog availability. */
    }

    requirement def MetadataContentRequirement {
        subject system : ISBNBasedBookSystem;
        doc /* The system shall include title, author, publisher, publication year, language, and format in the returned book metadata when available from the catalog. */
    }

    requirement def InvalidInputMessageRequirement {
        subject system : ISBNBasedBookSystem;
        doc /* The system shall return a clear rejection message when the entered ISBN is malformed, has an unsupported prefix, or fails check digit validation. */
    }

    satisfy ValidISBNRequirement by ISBNBasedBookSystem::validator;
    satisfy PrimaryFunctionRequirement by ISBNBasedBookSystem;
    satisfy LookupLatencyRequirement by ISBNBasedBookSystem::catalogGateway;
    satisfy MetadataContentRequirement by ISBNBasedBookSystem::composer;
    satisfy InvalidInputMessageRequirement by ISBNBasedBookSystem::validator;
}