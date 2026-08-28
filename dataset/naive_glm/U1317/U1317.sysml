package Stardraw {
    import ScalarValues::*;
    import ScalarFunctions::*;
    import ISQ::*;
    
    // Value Types
    value def Latitude :> Real { unit "deg"; }
    value def Longitude :> Real { unit "deg"; }
    value def Magnitude :> Real { unit "mag"; }
    value def RightAscension :> Real { unit "deg"; }
    value def Declination :> Real { unit "deg"; }
    value def FieldOfView :> Real { unit "deg"; }
    value def Scale :> Real { unit "px/deg"; }
    
    // Items
    item def ObservationParameters {
        lat : Latitude;
        lon : Longitude;
        time : DateTime;
        fov : FieldOfView;
        magLimit : Magnitude;
    }
    
    item def CelestialObject {
        ra : RightAscension;
        dec : Declination;
        mag : Magnitude;
        spectralType : String;
    }
    
    item def ChartSpecification {
        centerRa : RightAscension;
        centerDec : Declination;
        scale : Scale;
        visibleObjects : CelestialObject[*];
    }
    
    item def StarChart {
        format : String;
        resolution : Integer;
        imageData : String;
    }
    
    // Ports
    port def ParamPort {
        out params : ObservationParameters;
    }
    
    port def ObjectsPort {
        out objects : CelestialObject[*];
    }
    
    port def SpecPort {
        out spec : ChartSpecification;
    }
    
    port def ChartPort {
        out chart : StarChart;
    }
    
    // Parts
    part def ObservationInterface {
        port paramPort : ParamPort;
        attribute userParams : ObservationParameters;
        
        action def CaptureParameters {
            in req : ObservationParameters;
            out params : ObservationParameters;
        }
        
        action capture : CaptureParameters {
            in req = userParams;
            out paramPort.params;
        }
    }
    
    part def CelestialCatalog {
        port paramPort : ~ParamPort;
        port objectsPort : ObjectsPort;
        attribute catalog : CelestialObject[*];
        
        action def QueryCatalog {
            in params : ObservationParameters;
            in db : CelestialObject[*];
            out objects : CelestialObject[*];
        }
        
        action query : QueryCatalog {
            in params = paramPort.params;
            in db = catalog;
            out objectsPort.objects;
        }
    }
    
    part def ChartProcessor {
        port paramPort : ~ParamPort;
        port objectsPort : ~ObjectsPort;
        port specPort : SpecPort;
        
        action def ProcessData {
            in params : ObservationParameters;
            in objects : CelestialObject[*];
            out spec : ChartSpecification;
        }
        
        action process : ProcessData {
            in params = paramPort.params;
            in objects = objectsPort.objects;
            out specPort.spec;
        }
    }
    
    part def ChartRenderer {
        port specPort : ~SpecPort;
        port chartPort : ChartPort;
        
        action def RenderChart {
            in spec : ChartSpecification;
            out chart : StarChart;
        }
        
        action render : RenderChart {
            in spec = specPort.spec;
            out chartPort.chart;
        }
    }
    
    part def Stardraw {
        part observationInterface : ObservationInterface;
        part celestialCatalog : CelestialCatalog;
        part chartProcessor : ChartProcessor;
        part chartRenderer : ChartRenderer;
        
        interface paramsToCatalog : observationInterface.paramPort to celestialCatalog.paramPort;
        interface objectsToProcessor : celestialCatalog.objectsPort to chartProcessor.objectsPort;
        interface paramsToProcessor : observationInterface.paramPort to chartProcessor.paramPort;
        interface specToRenderer : chartProcessor.specPort to chartRenderer.specPort;
        
        state def Behavior {
            state idle;
            state receivingParameters;
            state queryingCatalog;
            state processingData;
            state renderingChart;
            state deliveringOutput;
            
            transition first idle then receivingParameters 
                when observationInterface.userParams != null;
                
            transition first receivingParameters then queryingCatalog 
                when observationInterface.paramPort.params != null;
                
            transition first queryingCatalog then processingData 
                when celestialCatalog.objectsPort.objects != null;
                
            transition first processingData then renderingChart 
                when chartProcessor.specPort.spec != null;
                
            transition first renderingChart then deliveringOutput 
                when chartRenderer.chartPort.chart != null;
                
            transition first deliveringOutput then idle 
                when chartRenderer.chartPort.chart == null;
        }
        
        state machine : Behavior;
    }
    
    // Requirements
    requirement def StardrawRequirements {
        subject stardraw : Stardraw;
        
        requirement captureParameters {
            subject : stardraw;
            doc /* The system shall capture observation parameters from the user. */
        }
        
        requirement queryCatalog {
            subject : stardraw;
            doc /* The system shall query the celestial catalog for objects within the specified area. */
        }
        
        requirement processChart {
            subject : stardraw;
            doc /* The system shall filter objects by magnitude and calculate chart specifications. */
        }
        
        requirement renderChart {
            subject : stardraw;
            doc /* The system shall render a high-resolution star chart image. */
        }
        
        requirement deliverChart {
            subject : stardraw;
            doc /* The system shall deliver the rendered star chart to the user. */
        }
    }
}
