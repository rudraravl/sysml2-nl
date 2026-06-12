package DefectDetectorSystemModel {
  import ScalarValues::*;
  import SI::*;

  item def ProductItem {
    attribute serialNumber : String;
    attribute width_mm : Real;
    attribute height_mm : Real;
  }

  item def ImageFrame {
    attribute frameId : String;
    attribute resolution_px : Integer;
    attribute exposure_ms : Real;
    attribute capturedAt_s : Real;
  }

  item def DefectFinding {
    attribute defectType : String;
    attribute confidence : Real;
    attribute x_mm : Real;
    attribute y_mm : Real;
    attribute size_mm2 : Real;
  }

  item def InspectionResult {
    attribute accepted : Boolean;
    attribute defectCount : Integer;
    attribute maxConfidence : Real;
  }

  port def ProductInputPort {
    in item product : ProductItem;
  }

  port def ProductOutputPort {
    out item product : ProductItem;
  }

  port def ImagePort {
    out item frame : ImageFrame;
  }

  port def ResultPort {
    out item result : InspectionResult;
  }

  port def CommandPort {
    in attribute startInspection : Boolean;
    in attribute stopInspection : Boolean;
    in attribute resetFault : Boolean;
  }

  port def StatusPort {
    out attribute ready : Boolean;
    out attribute faulted : Boolean;
    out attribute inspectedCount : Integer;
  }

  part def IlluminationUnit {
    attribute wavelength_nm : Real = 530.0;
    attribute intensity_lux : Real = 18000.0;
    attribute uniformity_percent : Real = 92.0;

    port commandIn : CommandPort;
    port statusOut : StatusPort;
  }

  part def CameraSensor {
    attribute resolution_px : Integer = 12000000;
    attribute frameRate_Hz : Real = 60.0;
    attribute exposure_ms : Real = 2.5;
    attribute fieldOfView_mm : Real = 220.0;

    port productIn : ProductInputPort;
    port imageOut : ImagePort;
    port statusOut : StatusPort;
  }

  part def ImageProcessor {
    attribute inferenceLatency_ms : Real = 18.0;
    attribute minDetectableDefect_mm2 : Real = 0.25;
    attribute classificationThreshold : Real = 0.87;

    port imageIn : ImagePort;
    port resultOut : ResultPort;
    port statusOut : StatusPort;
  }

  part def RejectMechanism {
    attribute actuationDelay_ms : Real = 45.0;
    attribute maxRejectRate_itemsPerMin : Real = 180.0;

    port resultIn : ResultPort;
    port productIn : ProductInputPort;
    port acceptedOut : ProductOutputPort;
    port rejectedOut : ProductOutputPort;
  }

  part def OperatorInterface {
    port commandOut : CommandPort;
    port statusIn : StatusPort;
    port resultIn : ResultPort;
  }

  part def DefectDetector {
    attribute primaryFunction : String =
      "Inspect products, detect surface or dimensional defects, classify each product, and route defective products for rejection.";
    attribute nominalLineRate_itemsPerMin : Real = 120.0;
    attribute probabilityOfDetection : Real = 0.985;
    attribute falseRejectRate : Real = 0.015;
    attribute operatingTemperature_C : Real = 25.0;

    port productIn : ProductInputPort;
    port acceptedProductOut : ProductOutputPort;
    port rejectedProductOut : ProductOutputPort;
    port operatorCommand : CommandPort;
    port detectorStatus : StatusPort;
    port inspectionResult : ResultPort;

    part illumination : IlluminationUnit;
    part camera : CameraSensor;
    part processor : ImageProcessor;
    part rejector : RejectMechanism;
    part ui : OperatorInterface;

    connect productIn to camera.productIn;
    connect productIn to rejector.productIn;
    connect camera.imageOut to processor.imageIn;
    connect processor.resultOut to rejector.resultIn;
    connect processor.resultOut to inspectionResult;
    connect rejector.acceptedOut to acceptedProductOut;
    connect rejector.rejectedOut to rejectedProductOut;
    connect operatorCommand to illumination.commandIn;
    connect ui.commandOut to operatorCommand;
    connect detectorStatus to ui.statusIn;
    connect inspectionResult to ui.resultIn;
  }

  action def AcquireImage {
    in item product : ProductItem;
    out item frame : ImageFrame;
  }

  action def AnalyzeImage {
    in item frame : ImageFrame;
    out item finding : DefectFinding;
    out item result : InspectionResult;
  }

  action def RouteProduct {
    in item product : ProductItem;
    in item result : InspectionResult;
    out item acceptedProduct : ProductItem;
    out item rejectedProduct : ProductItem;
  }

  action def DetectDefects {
    in item product : ProductItem;
    out item result : InspectionResult;

    action acquire : AcquireImage;
    action analyze : AnalyzeImage;

    flow product to acquire.product;
    flow acquire.frame to analyze.frame;
    flow analyze.result to result;

    succession acquire then analyze;
  }

  action def InspectAndSortProduct {
    in item product : ProductItem;
    out item acceptedProduct : ProductItem;
    out item rejectedProduct : ProductItem;
    out item result : InspectionResult;

    action detect : DetectDefects;
    action route : RouteProduct;

    flow product to detect.product;
    flow product to route.product;
    flow detect.result to result;
    flow detect.result to route.result;
    flow route.acceptedProduct to acceptedProduct;
    flow route.rejectedProduct to rejectedProduct;

    succession detect then route;
  }

  state def DetectorOperatingState {
    state Off;
    state Initializing;
    state Ready;
    state Inspecting;
    state Rejecting;
    state Faulted;
    state Maintenance;

    transition initial then Off;
    transition Off then Initializing
      accept StartCommand;
    transition Initializing then Ready
      accept SelfTestPassed;
    transition Initializing then Faulted
      accept SelfTestFailed;
    transition Ready then Inspecting
      accept ProductArrived;
    transition Inspecting then Ready
      accept ProductAccepted;
    transition Inspecting then Rejecting
      accept DefectDetected;
    transition Rejecting then Ready
      accept ProductRejected;
    transition Ready then Maintenance
      accept MaintenanceRequested;
    transition Maintenance then Ready
      accept MaintenanceComplete;
    transition Ready then Faulted
      accept CriticalFault;
    transition Inspecting then Faulted
      accept CriticalFault;
    transition Faulted then Initializing
      accept ResetCommand;
  }

  requirement def PrimaryFunctionRequirement {
    subject detector : DefectDetector;

    require constraint {
      detector.primaryFunction ==
      "Inspect products, detect surface or dimensional defects, classify each product, and route defective products for rejection."
    }
  }

  requirement def DetectionPerformanceRequirement {
    subject detector : DefectDetector;

    require constraint {
      detector.probabilityOfDetection >= 0.98 and
      detector.falseRejectRate <= 0.02
    }
  }

  requirement def ThroughputRequirement {
    subject detector : DefectDetector;

    require constraint {
      detector.nominalLineRate_itemsPerMin >= 100.0
    }
  }

  requirement def MinimumDefectSizeRequirement {
    subject processor : ImageProcessor;

    require constraint {
      processor.minDetectableDefect_mm2 <= 0.30
    }
  }

  requirement def InspectionLatencyRequirement {
    subject processor : ImageProcessor;

    require constraint {
      processor.inferenceLatency_ms <= 25.0
    }
  }

  requirement def RejectTimingRequirement {
    subject rejector : RejectMechanism;

    require constraint {
      rejector.actuationDelay_ms <= 60.0
    }
  }

  part defectDetectorSystem : DefectDetector;

  satisfy PrimaryFunctionRequirement by defectDetectorSystem;
  satisfy DetectionPerformanceRequirement by defectDetectorSystem;
  satisfy ThroughputRequirement by defectDetectorSystem;
  satisfy MinimumDefectSizeRequirement by defectDetectorSystem.processor;
  satisfy InspectionLatencyRequirement by defectDetectorSystem.processor;
  satisfy RejectTimingRequirement by defectDetectorSystem.rejector;
}