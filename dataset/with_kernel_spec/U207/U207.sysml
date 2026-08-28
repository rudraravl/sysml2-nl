package DrawingSheetManagementSystem {
    import ScalarValues::*;
    
    attribute def Length :> Real;
    attribute def ScaleFactor :> Real;
    attribute def Angle :> Real;
    
    enum def Orientation {
        literal portrait;
        literal landscape;
    }
    
    item def GeometricElement {
        attribute id : String;
        attribute positionX : Length;
        attribute positionY : Length;
    }
    
    item def Line {
        attribute id : String;
        attribute startX : Length;
        attribute startY : Length;
        attribute endX : Length;
        attribute endY : Length;
    }
    
    item def TextAnnotation {
        attribute id : String;
        attribute content : String;
        attribute positionX : Length;
        attribute positionY : Length;
    }
    
    item def Dimension {
        attribute id : String;
        attribute value : Length;
        attribute positionX : Length;
        attribute positionY : Length;
        attribute orientation : Angle;
    }
    
    item def RawDrawingData {
        attribute elements : GeometricElement[*];
        attribute lines : Line[*];
        attribute annotations : TextAnnotation[*];
        attribute dimensions : Dimension[*];
    }
    
    item def ValidationResult {
        attribute isValid : Boolean;
        attribute errors : String[*];
    }
    
    item def ScaledElement {
        attribute original : GeometricElement;
        attribute scale : ScaleFactor;
    }
    
    item def Layer {
        attribute name : String;
        attribute visible : Boolean;
        attribute locked : Boolean;
    }
    
    item def LayerAssignment {
        attribute elementID : String;
        attribute layerName : String;
    }
    
    item def PositionedElement {
        attribute element : ScaledElement;
        attribute finalX : Length;
        attribute finalY : Length;
        constraint { finalX >= 0 and finalY >= 0 }
    }
    
    item def ProjectMetadata {
        attribute projectName : String;
        attribute drawingNumber : String;
        attribute revision : String;
        attribute scale : ScaleFactor;
        attribute drawnBy : String;
        attribute checkedBy : String;
        attribute approvedBy : String;
    }
    
    item def SheetSize {
        attribute width : Length;
        attribute height : Length;
        constraint { width > 0 and height > 0 }
    }
    
    item def TitleBlockData {
        attribute projectMetadata : ProjectMetadata;
        attribute sheetSize : SheetSize;
    }
    
    item def LayoutConstraints {
        attribute margin : Length;
        attribute gridSpacing : Length;
        attribute snapToGrid : Boolean;
        constraint { margin >= 0 }
        constraint { gridSpacing > 0 }
    }
    
    item def DrawSheet {
        attribute sheetSize : SheetSize;
        attribute dimensions : SheetSize;
        attribute orientation : Orientation;
        attribute borderMargin : Length;
        attribute titleBlock : TitleBlockData;
        attribute layers : Layer[*];
        attribute positionedElements : PositionedElement[*];
        constraint { borderMargin >= 0 }
    }
    
    constraint def ElementsWithinBounds {
        in positionX : Length;
        in positionY : Length;
        in sheetWidth : Length;
        in sheetHeight : Length;
        in margin : Length;
        constraint positionX >= margin and positionX <= sheetWidth - margin and positionY >= margin and positionY <= sheetHeight - margin;
    }
    
    constraint def ScalingConsistent {
        in scale : ScaleFactor;
        in expectedScale : ScaleFactor;
        constraint scale == expectedScale;
    }
    
    constraint def LayoutFitsWithinMargins {
        in finalX : Length;
        in finalY : Length;
        in sheetWidth : Length;
        in sheetHeight : Length;
        in margin : Length;
        constraint finalX >= margin and finalX <= sheetWidth - margin and finalY >= margin and finalY <= sheetHeight - margin;
    }
    
    action def ValidateAction {
        in raw : RawDrawingData;
        in sheetWidth : Length;
        in sheetHeight : Length;
        in margin : Length;
        out validated : RawDrawingData;
        out result : ValidationResult;
    }
    
    action def ScaleAction {
        in raw : RawDrawingData;
        in factor : ScaleFactor;
        out scaled : ScaledElement[*];
    }
    
    action def AssignLayersAction {
        in elements : ScaledElement[*];
        out assignments : LayerAssignment[*];
        out layers : Layer[*];
    }
    
    action def LayoutAction {
        in assignments : LayerAssignment[*];
        in constraints : LayoutConstraints;
        in sheetWidth : Length;
        in sheetHeight : Length;
        out positioned : PositionedElement[*];
    }
    
    action def GenerateTitleBlockAction {
        in projectMetadata : ProjectMetadata;
        in sheet : SheetSize;
        out titleBlock : TitleBlockData;
    }
    
    action def AssembleSheet {
        in positionedElements : PositionedElement[*];
        in titleBlock : TitleBlockData;
        in sheetSize : SheetSize;
        in orientation : Orientation;
        in borderMargin : Length;
        in layers : Layer[*];
        out drawSheet : DrawSheet;
    }
    
    port def RawDataInPort {
        in data : RawDrawingData;
    }
    port def RawDataOutPort {
        out data : RawDrawingData;
    }
    port def ValidationResultOutPort {
        out result : ValidationResult;
    }
    port def ScaledDataOutPort {
        out elements : ScaledElement[*];
    }
    port def ScaledDataInPort {
        in elements : ScaledElement[*];
    }
    port def LayeredDataOutPort {
        out assignments : LayerAssignment[*];
        out layers : Layer[*];
    }
    port def LayeredDataInPort {
        in assignments : LayerAssignment[*];
        in layers : Layer[*];
    }
    port def PositionedDataOutPort {
        out elements : PositionedElement[*];
    }
    port def PositionedDataInPort {
        in elements : PositionedElement[*];
    }
    port def MetadataInPort {
        in projectMetadata : ProjectMetadata;
    }
    port def TitleBlockOutPort {
        out data : TitleBlockData;
    }
    port def DrawSheetOutPort {
        out sheet : DrawSheet;
    }
    
    part def ElementValidator {
        port inPort : RawDataInPort;
        port outPort : RawDataOutPort;
        port resultPort : ValidationResultOutPort;
        attribute sheetWidth : Length;
        attribute sheetHeight : Length;
        attribute margin : Length;
        action validate : ValidateAction;
        constraint { sheetWidth > 0 and sheetHeight > 0 and margin >= 0 }
    }
    
    part def Scaler {
        port inPort : RawDataInPort;
        attribute scaleIn : ScaleFactor;
        port outPort : ScaledDataOutPort;
        action scale : ScaleAction;
        constraint { scaleIn > 0 }
    }
    
    part def LayerManager {
        port inPort : ScaledDataInPort;
        port outPort : LayeredDataOutPort;
        action assignLayers : AssignLayersAction;
    }
    
    part def LayoutEngine {
        port inPort : LayeredDataInPort;
        attribute constraintsIn : LayoutConstraints;
        attribute sheetWidth : Length;
        attribute sheetHeight : Length;
        port outPort : PositionedDataOutPort;
        action layout : LayoutAction;
        constraint { sheetWidth > 0 and sheetHeight > 0 }
    }
    
    part def TitleBlockGenerator {
        port metadataIn : MetadataInPort;
        attribute sheetSizeIn : SheetSize;
        port outPort : TitleBlockOutPort;
        action generate : GenerateTitleBlockAction;
    }
    
    part def DrawingProcessor {
        port rawDataIn : RawDataInPort;
        port metadataIn : MetadataInPort;
        attribute constraintsIn : LayoutConstraints;
        attribute sheetSizeIn : SheetSize;
        attribute orientationIn : Orientation;
        attribute borderMarginIn : Length;
        attribute scaleFactor : ScaleFactor;
        port sheetOut : DrawSheetOutPort;
        
        part validator : ElementValidator;
        part scaler : Scaler;
        part layerManager : LayerManager;
        part layoutEngine : LayoutEngine;
        part titleBlockGen : TitleBlockGenerator;
        
        action assemble : AssembleSheet;
        
        bind rawDataIn = validator.inPort;
        bind metadataIn = titleBlockGen.metadataIn;
        bind validator.sheetWidth = sheetSizeIn.width;
        bind validator.sheetHeight = sheetSizeIn.height;
        bind validator.margin = constraintsIn.margin;
        bind scaler.scaleIn = scaleFactor;
        bind layoutEngine.constraintsIn = constraintsIn;
        bind layoutEngine.sheetWidth = sheetSizeIn.width;
        bind layoutEngine.sheetHeight = sheetSizeIn.height;
        bind titleBlockGen.sheetSizeIn = sheetSizeIn;
        bind assemble.sheetSize = sheetSizeIn;
        bind assemble.orientation = orientationIn;
        bind assemble.borderMargin = borderMarginIn;
        
        flow validatedDataFlow of RawDrawingData 
            from validator.outPort.data to scaler.inPort.data;
        flow scaledDataFlow of ScaledElement[*] 
            from scaler.outPort.elements to layerManager.inPort.elements;
        flow layeredAssignmentsFlow of LayerAssignment[*] 
            from layerManager.outPort.assignments to layoutEngine.inPort.assignments;
        flow layeredLayersFlow of Layer[*] 
            from layerManager.outPort.layers to assemble.layers;
        flow positionedDataFlow of PositionedElement[*] 
            from layoutEngine.outPort.elements to assemble.positionedElements;
        flow titleBlockFlow of TitleBlockData 
            from titleBlockGen.outPort.data to assemble.titleBlock;
        flow finalSheetFlow of DrawSheet 
            from assemble.drawSheet to sheetOut.sheet;
    }
    
    part drawingSystem : DrawingProcessor;
}
