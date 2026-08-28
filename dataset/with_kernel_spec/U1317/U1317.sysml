package Stardraw {
    private import ScalarValues::Real;
    private import ScalarValues::String;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;
    private import Time::TimeInstantValue;

    attribute def Latitude :> Real;
    attribute def Longitude :> Real;
    attribute def RightAscension :> Real;
    attribute def Declination :> Real;
    attribute def FieldOfView :> Real;
    attribute def Magnitude :> Real;
    attribute def SpectralType :> String;

    item def CelestialObject {
        attribute rightAscension : RightAscension [1];
        attribute declination : Declination [1];
        attribute magnitude : Magnitude [1];
        attribute spectralType : SpectralType [1];
    }

    item def ObservationParameters {
        attribute latitude : Latitude [1];
        attribute longitude : Longitude [1];
        attribute observationTime : TimeInstantValue [1];
        attribute fieldOfView : FieldOfView [1];
        attribute magnitudeLimit : Magnitude [1];
    }

    item def ChartSpecification {
        attribute centerRA : RightAscension [1];
        attribute centerDec : Declination [1];
        attribute scale : Real [1];
        attribute visibleObjects : CelestialObject [*];
    }

    item def ChartImage {
        attribute format : String [1];
        attribute resolutionX : Integer [1];
        attribute resolutionY : Integer [1];
    }

    attribute def ObservationRequest;
    attribute def ParametersCaptured;
    attribute def CatalogQueried;
    attribute def ChartProcessed;
    attribute def ChartRendered;
    attribute def ChartDelivered;

    port def ParametersPort {
        out parameters : ObservationParameters;
    }

    port def ObjectsPort {
        out objects : CelestialObject [*];
    }

    port def SpecPort {
        out specification : ChartSpecification;
    }

    port def ImagePort {
        out image : ChartImage;
    }

    calc def isWithinFieldOfView(objRA : RightAscension, objDec : Declination, centerRA : RightAscension, centerDec : Declination, fov : FieldOfView) : Boolean;

    calc def passesMagnitudeFilter(obj : CelestialObject, limit : Magnitude) : Boolean;

    action def CaptureParameters {
        in rawParameters : ObservationParameters;
        out capturedParameters : ObservationParameters;
    }

    action def QueryCatalog {
        in parameters : ObservationParameters;
        in allObjects : CelestialObject [*];
        out matchingObjects : CelestialObject [*];
    }

    action def ProcessChart {
        in objects : CelestialObject [*];
        in parameters : ObservationParameters;
        out specification : ChartSpecification;
    }

    action def RenderChart {
        in specification : ChartSpecification;
        out image : ChartImage;
    }

    part def ObservationInterface {
        port requestIn : ~ParametersPort;
        port parametersOut : ParametersPort;
        attribute capturedParameters : ObservationParameters [0..1];
    }

    part def CelestialCatalog {
        port parametersIn : ~ParametersPort;
        port objectsOut : ObjectsPort;
        attribute catalogData : CelestialObject [*];
        attribute matchedObjects : CelestialObject [*];
    }

    part def ChartProcessor {
        port objectsIn : ~ObjectsPort;
        port parametersIn : ~ParametersPort;
        port specOut : SpecPort;
        attribute inputObjects : CelestialObject [*];
        attribute processParameters : ObservationParameters [0..1];
        attribute outputSpec : ChartSpecification [0..1];
    }

    part def ChartRenderer {
        port specIn : ~SpecPort;
        port imageOut : ImagePort;
        attribute renderSpec : ChartSpecification [0..1];
        attribute renderedImage : ChartImage [0..1];
    }

    part def StardrawSystem {
        port requestPort : ~ParametersPort;
        port deliveryPort : ImagePort;

        part observationInterface : ObservationInterface;
        part celestialCatalog : CelestialCatalog;
        part chartProcessor : ChartProcessor;
        part chartRenderer : ChartRenderer;

        connect requestPort to observationInterface.requestIn;
        connect observationInterface.parametersOut to celestialCatalog.parametersIn;
        connect celestialCatalog.objectsOut to chartProcessor.objectsIn;
        connect observationInterface.parametersOut to chartProcessor.parametersIn;
        connect chartProcessor.specOut to chartRenderer.specIn;
        connect chartRenderer.imageOut to deliveryPort;

        attribute currentParameters : ObservationParameters [0..1];
        attribute currentObjects : CelestialObject [*];
        attribute currentSpec : ChartSpecification [0..1];
        attribute currentImage : ChartImage [0..1];

        state workflow {
            entry; then idle;
            state idle;
            accept ObservationRequest then receiving;
            state receiving;
            accept ParametersCaptured then querying;
            state querying;
            accept CatalogQueried then procChart;
            state procChart;
            accept ChartProcessed then rendering;
            state rendering;
            accept ChartRendered then delivering;
            state delivering;
            accept ChartDelivered then idle;
        }
    }

    requirement def CaptureUserParameters {
        text = "The ObservationInterface shall capture the user's geographical location (latitude and longitude), observation time, field of view, and magnitude limit.";
    }

    requirement def QueryCelestialCatalog {
        text = "The CelestialCatalog shall search its database and return all celestial objects within the specified field of view.";
    }

    requirement def FilterAndCalculateChart {
        text = "The ChartProcessor shall filter celestial objects by the user-specified magnitude limit and calculate the chart center, scale, and object placement.";
    }

    requirement def RenderChartImage {
        text = "The ChartRenderer shall generate a high-resolution PNG image of the star chart.";
    }

    requirement def SequentialWorkflow {
        text = "The system shall operate in a sequential workflow: idle, receive parameters, query catalog, process data, render chart, deliver output, and return to idle.";
    }

    satisfy CaptureUserParameters by StardrawSystem::observationInterface;
    satisfy QueryCelestialCatalog by StardrawSystem::celestialCatalog;
    satisfy FilterAndCalculateChart by StardrawSystem::chartProcessor;
    satisfy RenderChartImage by StardrawSystem::chartRenderer;
    satisfy SequentialWorkflow by StardrawSystem::workflow;
}
