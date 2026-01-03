package 'DrawSheetSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SheetDimensions {
		attribute width : LengthValue;
		attribute height : LengthValue;
		attribute thickness : LengthValue;
	}
	
	attribute def DrawingScale {
		attribute numerator : Real;
		attribute denominator : Real;
	}
	
	attribute def CoordinatePoint {
		attribute x : LengthValue;
		attribute y : LengthValue;
	}
	
	attribute def LineStyle {
		attribute weight : LengthValue;
		attribute pattern : String;
		attribute color : String;
	}
	
	item def DrawingLayer {
		attribute layerName : String;
		attribute isVisible : Boolean;
		attribute isLocked : Boolean;
		attribute elements : GraphicalElement[*];
	}
	
	item def GraphicalElement {
		attribute elementId : String;
		attribute position : CoordinatePoint;
		attribute style : LineStyle;
		attribute layerAssignment : String;
	}
	
	item def GeometricShape :> GraphicalElement {
		attribute vertices : CoordinatePoint[*];
		attribute isClosed : Boolean;
		attribute fillColor : String;
	}
	
	item def TextElement :> GraphicalElement {
		attribute content : String;
		attribute fontSize : LengthValue;
		attribute fontFamily : String;
		attribute justification : String;
	}
	
	item def DimensionAnnotation :> GraphicalElement {
		attribute startPoint : CoordinatePoint;
		attribute endPoint : CoordinatePoint;
		attribute measuredValue : LengthValue;
		attribute toleranceUpper : LengthValue;
		attribute toleranceLower : LengthValue;
	}
	
	item def TitleBlock {
		attribute projectName : String;
		attribute drawingNumber : String;
		attribute sheetNumber : String;
		attribute revision : String;
		attribute drawnBy : String;
		attribute checkedBy : String;
		attribute approvedBy : String;
		attribute dateDrawn : String;
		attribute dateChecked : String;
		attribute dateApproved : String;
		attribute scale : DrawingScale;
		attribute units : String;
	}
	
	item def DrawSheet {
		attribute sheetSize : SheetDimensions;
		attribute sheetFormat : String;
		attribute orientation : String;
		attribute scale : DrawingScale;
		attribute layers : DrawingLayer[*];
		attribute titleBlock : TitleBlock;
		attribute borderMargin : LengthValue;
	}
	
	port def DrawingInputPort {
		in item geometryData : GeometricShape[*];
		in item textData : TextElement[*];
		in item dimensionData : DimensionAnnotation[*];
		in attribute scaleInfo : DrawingScale;
	}
	
	port def DrawingOutputPort {
		out item completedSheet : DrawSheet;
		out attribute renderStatus : String;
	}
	
	port def LayerManagementPort {
		in attribute layerCommand : String;
		in attribute targetLayer : String;
		out attribute layerStatus : String;
	}
	
	port def ValidationPort {
		in item sheetToValidate : DrawSheet;
		out attribute validationResult : Boolean;
		out attribute validationMessages : String[*];
	}
	
	action def ValidateDrawingElements {
		in item inputGeometry : GeometricShape[*];
		in item inputText : TextElement[*];
		in item inputDimensions : DimensionAnnotation[*];
		in attribute sheetBounds : SheetDimensions;
		out attribute isValid : Boolean;
		out attribute errors : String[*];
	}
	
	action def OrganizeLayers {
		in item allElements : GraphicalElement[*];
		in attribute layerDefinitions : String[*];
		out item organizedLayers : DrawingLayer[*];
	}
	
	action def ApplyDrawingScale {
		in attribute targetScale : DrawingScale;
		in item originalElements : GraphicalElement[*];
		out item scaledElements : GraphicalElement[*];
	}
	
	action def PositionElements {
		in item elements : GraphicalElement[*];
		in attribute sheetBounds : SheetDimensions;
		in attribute margin : LengthValue;
		out item positionedElements : GraphicalElement[*];
		out attribute layoutComplete : Boolean;
	}
	
	action def GenerateTitleBlock {
		in attribute projectInfo : String;
		in attribute drawingInfo : String;
		in attribute scaleInfo : DrawingScale;
		in attribute personnel : String[*];
		out item titleBlock : TitleBlock;
	}
	
	action def AssembleDrawSheet {
		in item layers : DrawingLayer[*];
		in item titleBlock : TitleBlock;
		in attribute sheetSize : SheetDimensions;
		in attribute scale : DrawingScale;
		out item assembledSheet : DrawSheet;
	}
	
	action def RenderDrawing {
		in item sheet : DrawSheet;
		out attribute renderOutput : String;
		out attribute renderComplete : Boolean;
	}
	
	part def DrawingProcessor {
		attribute processingScale : DrawingScale;
		attribute activeSheetSize : SheetDimensions;
		
		port inputPort : DrawingInputPort;
		port outputPort : DrawingOutputPort;
		
		perform action processDrawing : ProcessDrawing;
	}
	
	part def LayerManager {
		attribute availableLayers : String[*];
		attribute activeLayer : String;
		
		port layerControl : LayerManagementPort;
		
		perform action manageLayers : ManageLayers;
	}
	
	part def ElementValidator {
		attribute validationRules : String[*];
		
		port validationPort : ValidationPort;
		
		perform action validateContent : ValidateDrawingElements;
	}
	
	part def LayoutEngine {
		attribute gridSpacing : LengthValue;
		attribute snapEnabled : Boolean;
		attribute alignmentTolerance : LengthValue;
		
		perform action arrangeElements : PositionElements;
	}
	
	part def TitleBlockGenerator {
		attribute standardFormat : String;
		attribute companyLogo : String;
		
		perform action createTitleBlock : GenerateTitleBlock;
	}
	
	action def ProcessDrawing {
		in item geometryInput : GeometricShape[*];
		in item textInput : TextElement[*];
		in item dimensionInput : DimensionAnnotation[*];
		in attribute targetScale : DrawingScale;
		in attribute targetSheetSize : SheetDimensions;
		in attribute projectMetadata : String[*];
		out item finalDrawSheet : DrawSheet;
		
		first start;
		then merge gatherInputs;
		
		action gatherInputs {
			out item collectedElements : GraphicalElement[*];
		}
		
		then action validateInputs : ValidateDrawingElements {
			in item inputGeometry = geometryInput;
			in item inputText = textInput;
			in item inputDimensions = dimensionInput;
			in attribute sheetBounds = targetSheetSize;
			out attribute isValid;
			out attribute errors;
		}
		
		then decide;
			if validateInputs.isValid then scaleElements;
			if !validateInputs.isValid then reportValidationErrors;
		
		action scaleElements : ApplyDrawingScale {
			in attribute targetScale = targetScale;
			in item originalElements = gatherInputs.collectedElements;
			out item scaledElements;
		}
		
		then action organizeLayers : OrganizeLayers {
			in item allElements = scaleElements.scaledElements;
			in attribute layerDefinitions[3] = ("Geometry", "Dimensions", "Annotations");
			out item organizedLayers;
		}
		
		then action positionElements : PositionElements {
			in item elements = scaleElements.scaledElements;
			in attribute sheetBounds = targetSheetSize;
			in attribute margin = 10.0 [mm];
			out item positionedElements;
			out attribute layoutComplete;
		}
		
		then action generateTitle : GenerateTitleBlock {
			in attribute projectInfo = projectMetadata[0];
			in attribute drawingInfo = projectMetadata[1];
			in attribute scaleInfo = targetScale;
			in attribute personnel = projectMetadata;
			out item titleBlock;
		}
		
		then action assembleSheet : AssembleDrawSheet {
			in item layers = organizeLayers.organizedLayers;
			in item titleBlock = generateTitle.titleBlock;
			in attribute sheetSize = targetSheetSize;
			in attribute scale = targetScale;
			out item assembledSheet;
		}
		
		then action renderOutput : RenderDrawing {
			in item sheet = assembleSheet.assembledSheet;
			out attribute renderOutput;
			out attribute renderComplete;
		}
		
		then assign finalDrawSheet := assembleSheet.assembledSheet;
		then done;
		
		action reportValidationErrors {
			in attribute errorMessages = validateInputs.errors;
		}
		then done;
	}
	
	action def ManageLayers {
		in attribute command : String;
		in attribute targetLayerName : String;
		out attribute operationStatus : String;
		
		first start;
		then decide;
			if command == "show" then showLayer;
			if command == "hide" then hideLayer;
			if command == "lock" then lockLayer;
			if command == "unlock" then unlockLayer;
		
		action showLayer {
			private attribute layerVisible : Boolean := true;
		}
		then done;
		
		action hideLayer {
			private attribute layerVisible : Boolean := false;
		}
		then done;
		
		action lockLayer {
			private attribute layerLocked : Boolean := true;
		}
		then done;
		
		action unlockLayer {
			private attribute layerLocked : Boolean := false;
		}
		then done;
	}
	
	part def DrawSheetManagementSystem {
		doc /* 
			The Draw Sheet Management System is a comprehensive technical drawing 
			production system that organizes, scales, validates, and renders engineering 
			drawings on standardized sheet formats. Its primary function is to accept 
			geometric shapes, text annotations, and dimensional information from design 
			sources, then compose them into properly formatted, scaled, and annotated 
			technical drawings complete with title blocks, layer organization, and 
			validation checks to ensure drawing standards compliance.
		*/
		
		attribute systemScale : DrawingScale {
			attribute :>> numerator = 1.0;
			attribute :>> denominator = 50.0;
		}
		
		attribute standardSheetSize : SheetDimensions {
			attribute :>> width = 841.0 [mm];
			attribute :>> height = 594.0 [mm];
			attribute :>> thickness = 0.1 [mm];
		}
		
		attribute defaultMargin : LengthValue = 15.0 [mm];
		
		part processor : DrawingProcessor {
			attribute :>> processingScale = systemScale;
			attribute :>> activeSheetSize = standardSheetSize;
		}
		
		part layerMgr : LayerManager {
			attribute :>> availableLayers[5] = ("Border", "Geometry", "Dimensions", "Annotations", "TitleBlock");
			attribute :>> activeLayer = "Geometry";
		}
		
		part validator : ElementValidator {
			attribute :>> validationRules[3] = ("BoundsCheck", "OverlapDetection", "ScaleConsistency");
		}
		
		part layoutEngine : LayoutEngine {
			attribute :>> gridSpacing = 5.0 [mm];
			attribute :>> snapEnabled = true;
			attribute :>> alignmentTolerance = 0.5 [mm];
		}
		
		part titleBlockGen : TitleBlockGenerator {
			attribute :>> standardFormat = "ISO7200";
			attribute :>> companyLogo = "CompanyLogoPath";
		}
		
		connection dataFlow connect processor.inputPort to layoutEngine;
		connection validationFlow connect validator.validationPort to processor;
		connection layerControl connect layerMgr.layerControl to processor;
		connection titleBlockFlow connect titleBlockGen to processor;
	}
	
	requirement def DrawingAccuracyRequirement {
		doc /* All geometric elements shall be positioned with accuracy within 0.05mm of specified coordinates. */
		
		subject system : DrawSheetManagementSystem;
		
		require constraint {
			system.layoutEngine.alignmentTolerance <= 0.5 [mm]
		}
	}
	
	requirement def ScaleConsistencyRequirement {
		doc /* The drawing scale shall be consistently applied to all geometric elements and properly documented in the title block. */
		
		subject system : DrawSheetManagementSystem;
		
		require constraint {
			system.systemScale.numerator > 0.0 and
			system.systemScale.denominator > 0.0
		}
	}
	
	requirement def SheetFormatComplianceRequirement {
		doc /* The system shall support standard ISO 5457 and ANSI Y14.1 sheet formats with proper border and title block placement. */
		
		subject system : DrawSheetManagementSystem;
		
		require constraint {
			system.defaultMargin >= 10.0 [mm] and
			system.defaultMargin <= 25.0 [mm]
		}
	}
	
	requirement def LayerOrganizationRequirement {
		doc /* Drawing elements shall be organized into logical layers with independent visibility and lock controls. */
		
		subject system : DrawSheetManagementSystem;
		
		require constraint {
			system.layerMgr.availableLayers->size() >= 3
		}
	}
	
	requirement <'REQ-DS-001'> primaryDrawSheetRequirement {
		doc /* The Draw Sheet Management System shall produce complete, standards-compliant technical drawings from input geometry, annotations, and dimensions. */
		
		subject drawSystem : DrawSheetManagementSystem;
		
		assume constraint { drawSystem.systemScale.denominator > 0.0 }
		
		require accuracyReq : DrawingAccuracyRequirement {
			redefines system = drawSystem;
		}
		
		require scaleReq : ScaleConsistencyRequirement {
			redefines system = drawSystem;
		}
		
		require formatReq : SheetFormatComplianceRequirement {
			redefines system = drawSystem;
		}
		
		require layerReq : LayerOrganizationRequirement {
			redefines system = drawSystem;
		}
	}
	
	part drawSheetSystemInstance : DrawSheetManagementSystem {
		perform action mainDrawingProcess : ProcessDrawing {
			in item geometryInput[*];
			in item textInput[*];
			in item dimensionInput[*];
			in attribute targetScale = systemScale;
			in attribute targetSheetSize = standardSheetSize;
			in attribute projectMetadata[6] = (
				"Mechanical Assembly Project",
				"DWG-MA-2024-001",
				"John Smith",
				"Jane Doe",
				"Robert Johnson",
				"2024-01-20"
			);
			out item finalDrawSheet;
		}
	}
}
