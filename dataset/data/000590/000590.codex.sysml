package DrawSheetSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def SheetIdentifier : String;
    attribute def RevisionCode : String;
    attribute def DrawingTitle : String;

    item def DrawingSheet {
        attribute sheetId : SheetIdentifier;
        attribute title : DrawingTitle;
        attribute revision : RevisionCode;
        attribute width : LengthValue;
        attribute height : LengthValue;
        attribute scaleRatio : Real;
        attribute issueDate : String;
    }

    item def DrawingFeature {
        attribute featureId : String;
        attribute layerName : String;
        attribute geometryType : String;
        attribute nominalX : LengthValue;
        attribute nominalY : LengthValue;
    }

    item def DimensionCallout {
        attribute calloutId : String;
        attribute measuredValue : LengthValue;
        attribute tolerancePlus : LengthValue;
        attribute toleranceMinus : LengthValue;
    }

    item def DrawingInterpretation {
        attribute interpretedTitle : DrawingTitle;
        attribute interpretedRevision : RevisionCode;
        attribute featureCount : Integer;
        attribute dimensionCount : Integer;
        attribute completenessScore : Real;
    }

    item def SystemDefinition {
        attribute systemName : String;
        attribute primaryFunction : String;
        attribute sourceSheetId : SheetIdentifier;
        attribute sourceRevision : RevisionCode;
        attribute confidence : Real;
    }

    port def SheetInputPort {
        in item sheet : DrawingSheet;
        in item features : DrawingFeature[*];
        in item dimensions : DimensionCallout[*];
    }

    port def DefinitionOutputPort {
        out item definition : SystemDefinition;
        out item interpretation : DrawingInterpretation;
    }

    port def ReviewPort {
        out item reviewPackage : DrawingInterpretation;
        in item approvalDecision : String;
    }

    action def ValidateDrawSheet {
        in item sheet : DrawingSheet;
        in item features : DrawingFeature[*];
        in item dimensions : DimensionCallout[*];
        out valid : Boolean;
    }

    action def InterpretDrawSheet {
        in item sheet : DrawingSheet;
        in item features : DrawingFeature[*];
        in item dimensions : DimensionCallout[*];
        out item interpretation : DrawingInterpretation;
    }

    action def DefineSystemFromSheet {
        in item sheet : DrawingSheet;
        in item interpretation : DrawingInterpretation;
        out item definition : SystemDefinition;
    }

    action def PublishSystemDefinition {
        in item definition : SystemDefinition;
        in item interpretation : DrawingInterpretation;
        out published : Boolean;
    }

    part def DrawSheetBasedSystem {
        attribute systemName : String = "Draw Sheet Based System";
        attribute primaryFunction : String =
            "Convert the information contained on a controlled draw sheet into a validated high-level system definition that identifies the system, its major drawn features, dimensional basis, and intended primary function.";
        attribute minimumCompletenessScore : Real = 0.95;
        attribute maximumSheetWidth : LengthValue = 1189 [mm];
        attribute maximumSheetHeight : LengthValue = 841 [mm];

        port sheetInput : SheetInputPort;
        port definitionOutput : DefinitionOutputPort;
        port reviewInterface : ReviewPort;

        part sheetRepository {
            attribute storedSheetCount : Integer;
            port acceptedSheetInput : SheetInputPort;
        }

        part validationProcessor {
            attribute requiredTitleBlockPresent : Boolean;
            attribute requiredRevisionPresent : Boolean;
            attribute validGeometryPresent : Boolean;
        }

        part interpretationProcessor {
            attribute recognizedFeatureCount : Integer;
            attribute recognizedDimensionCount : Integer;
            attribute derivedCompletenessScore : Real;
        }

        part systemDefinitionProcessor {
            attribute generatedSystemName : String;
            attribute generatedPrimaryFunction : String;
            attribute definitionConfidence : Real;
        }

        part reviewController {
            attribute currentReviewState : String;
            attribute reviewerDecision : String;
        }

        connection sheetRouting
            connect sheetInput to sheetRepository.acceptedSheetInput;

        connection reviewRouting
            connect definitionOutput.interpretation to reviewInterface.reviewPackage;

        perform action validateSheet : ValidateDrawSheet {
            in sheet = sheetInput.sheet;
            in features = sheetInput.features;
            in dimensions = sheetInput.dimensions;
        }

        perform action interpretSheet : InterpretDrawSheet {
            in sheet = sheetInput.sheet;
            in features = sheetInput.features;
            in dimensions = sheetInput.dimensions;
        }

        perform action defineSystem : DefineSystemFromSheet {
            in sheet = sheetInput.sheet;
            in interpretation = interpretSheet.interpretation;
        }

        perform action publishDefinition : PublishSystemDefinition {
            in definition = defineSystem.definition;
            in interpretation = interpretSheet.interpretation;
        }

        state def DefinitionLifecycle {
            state awaitingSheet;
            state validatingSheet;
            state interpretingSheet;
            state definingSystem;
            state awaitingReview;
            state published;
            state rejected;

            initial then awaitingSheet;

            transition awaitingSheet_to_validatingSheet
                first awaitingSheet
                accept sheetInput.sheet
                then validatingSheet;

            transition validatingSheet_to_interpretingSheet
                first validatingSheet
                if validateSheet.valid
                then interpretingSheet;

            transition validatingSheet_to_rejected
                first validatingSheet
                if not validateSheet.valid
                then rejected;

            transition interpretingSheet_to_definingSystem
                first interpretingSheet
                if interpretationProcessor.derivedCompletenessScore >= minimumCompletenessScore
                then definingSystem;

            transition interpretingSheet_to_rejected
                first interpretingSheet
                if interpretationProcessor.derivedCompletenessScore < minimumCompletenessScore
                then rejected;

            transition definingSystem_to_awaitingReview
                first definingSystem
                then awaitingReview;

            transition awaitingReview_to_published
                first awaitingReview
                accept reviewInterface.approvalDecision
                if reviewController.reviewerDecision == "Approved"
                then published;

            transition awaitingReview_to_rejected
                first awaitingReview
                accept reviewInterface.approvalDecision
                if reviewController.reviewerDecision == "Rejected"
                then rejected;
        }
    }

    requirement def DrawSheetBasisRequirement {
        subject system : DrawSheetBasedSystem;
        require constraint {
            system.sheetInput.sheet.sheetId != "";
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : DrawSheetBasedSystem;
        require constraint {
            system.primaryFunction != "";
        }
    }

    requirement def SheetSizeRequirement {
        subject system : DrawSheetBasedSystem;
        require constraint {
            system.sheetInput.sheet.width <= system.maximumSheetWidth and
            system.sheetInput.sheet.height <= system.maximumSheetHeight;
        }
    }

    requirement def InterpretationCompletenessRequirement {
        subject system : DrawSheetBasedSystem;
        require constraint {
            system.interpretationProcessor.derivedCompletenessScore >=
            system.minimumCompletenessScore;
        }
    }

    requirement def TraceableDefinitionRequirement {
        subject definition : SystemDefinition;
        require constraint {
            definition.sourceSheetId != "" and
            definition.sourceRevision != "";
        }
    }

    part drawSheetDefinitionSystem : DrawSheetBasedSystem {
        attribute systemName = "Controlled Draw Sheet Definition System";
        attribute primaryFunction =
            "Interpret a controlled draw sheet and produce a traceable high-level definition of the represented system and its primary function.";
    }

    satisfy DrawSheetBasisRequirement by drawSheetDefinitionSystem;
    satisfy PrimaryFunctionRequirement by drawSheetDefinitionSystem;
    satisfy SheetSizeRequirement by drawSheetDefinitionSystem;
    satisfy InterpretationCompletenessRequirement by drawSheetDefinitionSystem;
}