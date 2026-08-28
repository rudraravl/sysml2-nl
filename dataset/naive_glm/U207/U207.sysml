package DrawingSheetManagementSystem {
    import ScalarFunctions::*;
    import SI::Length;
    import SI::Dimensionless;
    
    // ===== Value Types with Units =====
    
    value type LengthUnit {
        doc: "Length unit in millimeters";
        unit: "mm" := mm;
    }
    
    value type LengthMM :> Real {
        doc: "Length in millimeters";
        unit: mm;
    }
    
    value type Scale :> Real {
        doc: "Drawing scale ratio";
    }
    
    value type RotationAngle :> Real {
        doc: "Rotation angle in degrees";
        unit: "deg";
    }
    
    value type ColorValue :> Integer {
        doc: "8-bit color channel value (0..255)";
    }
    
    // ===== Enumerations =====
    
    enum def SheetSize {
        A0;
        A1;
        A2;
        A3;
        A4;
        A5;
    }
    
    enum def Orientation {
        Landscape;
        Portrait;
    }
    
    enum def LayerState {
        VisibleUnlocked;
        VisibleLocked;
        Hidden;
    }
    
    enum def ValidationStatus {
        Valid;
        Invalid_BoundaryViolation;
        Invalid_ScaleInconsistent;
        Invalid_MissingMetadata;
    }
    
    enum def ProcessingState {
        Idle;
        Validating;
        Scaling;
        Layering;
        Layout;
        GeneratingTitleBlock;
        Assembling;
        Complete;
        Error;
    }
    
    // ===== Attribute Definitions =====
    
    attribute def Color {
        attribute red : ColorValue;
        attribute green : ColorValue;
        attribute blue : ColorValue;
    }
    
    attribute def Point2D {
        attribute x : LengthMM;
        attribute y : LengthMM;
    }
    
    attribute def Rect2D {
        attribute origin : Point2D;
        attribute width : LengthMM;
        attribute height : LengthMM;
    }
    
    attribute def Margin {
        attribute top : LengthMM;
        attribute bottom : LengthMM;
        attribute left : LengthMM;
        attribute right : LengthMM;
    }
    
    attribute def GridConfig {
        attribute gridSize : LengthMM;
        attribute snappingEnabled : Boolean;
        attribute snappingTolerance : LengthMM;
    }
    
    // ===== Item Definitions =====
    
    item def GeometricShape {
        doc: "Base item for any geometric shape element";
        attribute id : String;
        attribute layerName : String;
        attribute color : Color;
        attribute origin : Point2D;
        attribute rotation : RotationAngle default 0;
        attribute locked : Boolean default false;
    }
    
    item def Line :> GeometricShape {
        attribute start : Point2D;
        attribute end : Point2D;
        attribute thickness : LengthMM;
    }
    
    item def Circle :> GeometricShape {
        attribute center : Point2D;
        attribute radius : LengthMM;
        attribute thickness : LengthMM;
    }
    
    item def Arc :> GeometricShape {
        attribute center : Point2D;
        attribute radius : LengthMM;
        attribute startAngle : RotationAngle;
        attribute endAngle : RotationAngle;
        attribute thickness : LengthMM;
    }
    
    item def Polygon :> GeometricShape {
        attribute vertices : Point2D[2..*];
        attribute closed : Boolean;
    }
    
    item def TextNote {
        doc: "Textual annotation element";
        attribute id : String;
        attribute layerName : String;
        attribute origin : Point2D;
        attribute content : String;
        attribute fontSize : LengthMM;
        attribute color : Color;
        attribute locked : Boolean default false;
    }
    
    item def DimensionAnnotation {
        doc: "Dimension/measure annotation element";
        attribute id : String;
        attribute layerName : String;
        attribute measuredLine : Line;
        attribute extension1 : Line;
        attribute extension2 : Line;
        attribute textValue : String;
        attribute textPosition : Point2D;
        attribute color : Color;
        attribute locked : Boolean default false;
    }
    
    item def DrawingElement {
        doc: "Union concept of all renderable elements";
    }
    
    item def RawDesignData {
        doc: "Raw input design data";
        item shapes : GeometricShape[0..*];
        item notes : TextNote[0..*];
        item dimensions : DimensionAnnotation[0..*];
        attribute projectName : String;
        attribute drawingNumber : String;
        attribute revision : String;
        attribute authorName : String;
        attribute checkerName : String;
        attribute approverName : String;
    }
    
    item def Layer {
        attribute name : String;
        attribute description : String;
        attribute state : LayerState;
        attribute elementCount : Integer;
    }
    
    item def ProjectMetadata {
        attribute projectName : String;
        attribute drawingNumber : String;
        attribute revision : String;
        attribute scale : Scale;
        attribute authorName : String;
        attribute checkerName : String;
        attribute approverName : String;
        attribute sheetSize : SheetSize;
        attribute orientation : Orientation;
        attribute company : String;
        attribute standard : String default "ISO 7200";
        attribute dateCreated : String;
        attribute dateChecked : String;
        attribute dateApproved : String;
    }
    
    item def DrawSheet {
        doc: "Digital blueprint output";
        attribute sheetSize : SheetSize;
        attribute orientation : Orientation;
        attribute sheetDimensions : Rect2D;
        attribute borderMargin : Margin;
        attribute scale : Scale;
        item titleBlock : TitleBlock;
        item layers : Layer[0..*];
        item elements : DrawingElement[0..*];
        attribute generationTimestamp : String;
        attribute standard : String;
    }
    
    item def TitleBlock {
        attribute position : Rect2D;
        attribute metadata : ProjectMetadata;
        attribute fieldCount : Integer;
    }
    
    // ===== Ports =====
    
    port def DesignDataInput {
        in item rawDesignData : RawDesignData;
        in attribute targetSheetSize : SheetSize;
        in attribute targetOrientation : Orientation;
        in attribute targetScale : Scale;
    }
    
    port def ValidationPort {
        in item rawDesignData : RawDesignData;
        in attribute sheetSize : SheetSize;
        in attribute sheetDimensions : Rect2D;
        out attribute status : ValidationStatus;
        out item validatedData : RawDesignData;
    }
    
    port def LayerManagementPort {
        in item elements : GeometricShape[0..*];
        in item notes : TextNote[0..*];
        in item dimensions : DimensionAnnotation[0..*];
        out item layers : Layer[0..*];
        out item layeredElements : DrawingElement[0..*];
    }
    
    port def LayoutPort {
        in item elements : DrawingElement[0..*];
        in attribute sheetDimensions : Rect2D;
        in attribute borderMargin : Margin;
        in attribute gridConfig : GridConfig;
        out item positionedElements : DrawingElement[0..*];
    }
    
    port def TitleBlockPort {
        in attribute metadata : ProjectMetadata;
        in attribute sheetDimensions : Rect2D;
        in attribute borderMargin : Margin;
        out item titleBlock : TitleBlock;
    }
    
    port def DrawSheetOutput {
        out item drawSheet : DrawSheet;
    }
    
    // ===== Interfaces =====
    
    interface def ValidationInterface {
        end source : ValidationPort;
        end target : ValidationPort;
    }
    
    interface def LayerManagementInterface {
        end source : LayerManagementPort;
        end target : LayerManagementPort;
    }
    
    interface def LayoutInterface {
        end source : LayoutPort;
        end target : LayoutPort;
    }
    
    interface def TitleBlockInterface {
        end source : TitleBlockPort;
        end target : TitleBlockPort;
    }
    
    // ===== Requirements =====
    
    requirement def SheetDimensionRequirement {
        doc: "Drawing sheet must conform to ISO sizes.";
        attribute sheetSize : SheetSize;
        attribute orientation : Orientation;
        require {
            /* Dimensions must match ISO standard */
        }
    }
    
    requirement def BorderMarginRequirement {
        doc: "Each sheet must have a defined border margin.";
        attribute borderMargin : Margin;
        require borderMargin.top > 0 & borderMargin.bottom > 0 & 
                borderMargin.left > 0 & borderMargin.right > 0;
    }
    
    requirement def TitleBlockRequirement {
        doc: "Each sheet must have an automatically generated, populated title block.";
        require titleBlock.metadata.projectName != "" & 
                titleBlock.metadata.drawingNumber != "" &
                titleBlock.metadata.revision != "" &
                titleBlock.metadata.authorName != "" &
                titleBlock.metadata.checkerName != "" &
                titleBlock.metadata.approverName != "";
    }
    
    requirement def LayerRequirement {
        doc: "Content must be organized into layers including geometry, dimensions, and text.";
        require layers->exists(name = "Geometry") & 
                layers->exists(name = "Dimensions") &
                layers->exists(name = "Text");
    }
    
    requirement def ValidationRequirement {
        doc: "All elements must be validated before processing.";
        require status = ValidationStatus::Valid;
    }
    
    requirement def ScaleRequirement {
        doc: "All elements must be scaled to the specified drawing scale.";
        attribute scale : Scale;
        require scale > 0;
    }
    
    // ===== State Machine =====
    
    state def DrawingProcessingStateMachine {
        doc: "State machine governing the Drawing Processor workflow.";
        
        state Idle {
            entry;
            do;
            exit;
        }
        
        state Validating {
            entry;
            do;
            exit;
        }
        
        state Scaling {
            entry;
            do;
            exit;
        }
        
        state Layering {
            entry;
            do;
            exit;
        }
        
        state Layout {
            entry;
            do;
            exit;
        }
        
        state GeneratingTitleBlock {
            entry;
            do;
            exit;
        }
        
        state Assembling {
            entry;
            do;
            exit;
        }
        
        state Complete {
            entry;
            do;
            exit;
        }
        
        state Error {
            entry;
            do;
            exit;
        }
        
        transition valid_Start {
            from Idle;
            to Validating;
            trigger;
            guard;
            effect;
        }
        
        transition valid_OK {
            from Validating;
            to Scaling;
            guard status == ValidationStatus::Valid;
        }
        
        transition invalid_Error {
            from Validating;
            to Error;
            guard status != ValidationStatus::Valid;
        }
        
        transition scaling_Done {
            from Scaling;
            to Layering;
        }
        
        transition layering_Done {
            from Layering;
            to Layout;
        }
        
        transition layout_Done {
            from Layout;
            to GeneratingTitleBlock;
        }
        
        transition titleBlock_Done {
            from GeneratingTitleBlock;
            to Assembling;
        }
        
        transition assembled {
            from Assembling;
            to Complete;
        }
        
        transition reset {
            from Complete;
            to Idle;
        }
        
        transition errorRecovery {
            from Error;
            to Idle;
        }
    }
    
    // ===== Part Definitions =====
    
    part def ElementValidator {
        doc: "Validates raw input design data against drawing rules.";
        port inValidation : ValidationPort;
        attribute validationLog : String[0..*];
        
        action validate :> Action {
            in raw : RawDesignData;
            in sheetDims : Rect2D;
            out status : ValidationStatus;
            out validated : RawDesignData;
            
            // Check elements within boundaries
            // Check scaling consistency
            // Verify metadata presence
        }
    }
    
    part def LayerManager {
        doc: "Organizes content into distinct layers.";
        port inLayers : LayerManagementPort;
        port outLayers : LayerManagementPort;
        attribute defaultLayerState : LayerState = VisibleUnlocked;
        
        action assignToLayers :> Action {
            in shapes : GeometricShape[0..*];
            in notes : TextNote[0..*];
            in dimensions : DimensionAnnotation[0..*];
            out layers : Layer[0..*];
            out layered : DrawingElement[0..*];
        }
        
        action setLayerState :> Action {
            in layerName : String;
            in newState : LayerState;
        }
    }
    
    part def LayoutEngine {
        doc: "Arranges graphical elements using grid snapping and alignment rules.";
        port inLayout : LayoutPort;
        port outLayout : LayoutPort;
        attribute gridConfig : GridConfig;
        
        action positionElements :> Action {
            in elements : DrawingElement[0..*];
            in sheetDims : Rect2D;
            in margin : Margin;
            in grid : GridConfig;
            out positioned : DrawingElement[0..*];
        }
        
        action snapToGrid :> Action {
            in p : Point2D;
            in grid : GridConfig;
            out snapped : Point2D;
        }
    }
    
    part def TitleBlockGenerator {
        doc: "Generates ISO 7200 compliant title blocks.";
        port inTitle : TitleBlockPort;
        port outTitle : TitleBlockPort;
        attribute standard : String = "ISO 7200";
        
        action generateTitleBlock :> Action {
            in metadata : ProjectMetadata;
            in sheetDims : Rect2D;
            in margin : Margin;
            out titleBlock : TitleBlock;
        }
        
        action populateFields :> Action {
            in metadata : ProjectMetadata;
            in titleBlock : TitleBlock;
            out filled : TitleBlock;
        }
    }
    
    part def DrawingProcessor {
        doc: "Central orchestrator for the drawing sheet generation workflow.";
        port input : DesignDataInput;
        port output : DrawSheetOutput;
        port validatorPort : ValidationPort;
        port layerManagerPort : LayerManagementPort;
        port layoutEnginePort : LayoutPort;
        port titleBlockPort : TitleBlockPort;
        
        attribute currentState : ProcessingState = Idle;
        
        exhibit state machine : DrawingProcessingStateMachine;
        
        action orchestrate :> Action {
            in raw : RawDesignData;
            in sheetSize : SheetSize;
            in orientation : Orientation;
            in scale : Scale;
            out sheet : DrawSheet;
        }
        
        action calculateSheetDimensions :> Action {
            in size : SheetSize;
            in orientation : Orientation;
            out dims : Rect2D;
        }
        
        action computeBorderMargin :> Action {
            in size : SheetSize;
            out margin : Margin;
        }
        
        action assembleSheet :> Action {
            in positionedElements : DrawingElement[0..*];
            in titleBlock : TitleBlock;
            in layers : Layer[0..*];
            in metadata : ProjectMetadata;
            in dims : Rect2D;
            in margin : Margin;
            out sheet : DrawSheet;
        }
    }
    
    // ===== Action Definitions =====
    
    action def ValidateData {
        in raw : RawDesignData;
        in sheetDims : Rect2D;
        out status : ValidationStatus;
        out validated : RawDesignData;
    }
    
    action def ScaleElements {
        in raw : RawDesignData;
        in scale : Scale;
        out scaledShapes : GeometricShape[0..*];
        out scaledDimensions : DimensionAnnotation[0..*];
        out scaledNotes : TextNote[0..*];
    }
    
    action def OrganizeLayers {
        in shapes : GeometricShape[0..*];
        in notes : TextNote[0..*];
        in dimensions : DimensionAnnotation[0..*];
        out layers : Layer[0..*];
        out layeredElements : DrawingElement[0..*];
    }
    
    action def PositionElements {
        in elements : DrawingElement[0..*];
        in dims : Rect2D;
        in margin : Margin;
        in grid : GridConfig;
        out positioned : DrawingElement[0..*];
    }
    
    action def GenerateTitle {
        in metadata : ProjectMetadata;
        in dims : Rect2D;
        in margin : Margin;
        out titleBlock : TitleBlock;
    }
    
    // ===== Top-level System =====
    
    part def DrawingSheetManagementSystem {
        doc: "Comprehensive system for automatically generating professional technical drawings.";
        
        part processor : DrawingProcessor;
        part validator : ElementValidator;
        part layerManager : LayerManager;
        part layoutEngine : LayoutEngine;
        part titleBlockGen : TitleBlockGenerator;
        
        connection validatorConn connect processor.validatorPort to validator.inValidation;
        connection layerMgrConn connect processor.layerManagerPort to layerManager.inLayers;
        connection layoutConn connect processor.layoutEnginePort to layoutEngine.inLayout;
        connection titleBlockConn connect processor.titleBlockPort to titleBlockGen.inTitle;
        
        requirement :> SheetDimensionRequirement;
        requirement :> BorderMarginRequirement;
        requirement :> TitleBlockRequirement;
        requirement :> LayerRequirement;
        requirement :> ValidationRequirement;
        requirement :> ScaleRequirement;
        
        action runWorkflow :> Action {
            doc: "End-to-end workflow: validate, scale, layer, layout, title block, assemble.";
            in rawInput : RawDesignData;
            in sheetSize : SheetSize;
            in orientation : Orientation;
            in scale : Scale;
            out drawSheet : DrawSheet;
        }
    }
}
