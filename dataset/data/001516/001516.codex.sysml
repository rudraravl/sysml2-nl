package OpenSourceVisionInspectionSystem {

  import ScalarValues::*;
  import SI::*;

  item def ImageFrame {
    attribute width : Integer;
    attribute height : Integer;
    attribute channels : Integer;
    attribute timestamp : Real;
  }

  item def DetectionResult {
    attribute classLabel : String;
    attribute confidence : Real;
    attribute xCenter_px : Real;
    attribute yCenter_px : Real;
    attribute width_px : Real;
    attribute height_px : Real;
  }

  item def InspectionDecision {
    attribute accepted : Boolean;
    attribute reason : String;
    attribute confidence : Real;
  }

  value def FrameRate {
    unit = "Hz";
    quantityKind = "frequency";
  }

  value def Latency {
    unit = "ms";
    quantityKind = "time";
  }

  value def Power {
    unit = "W";
    quantityKind = "power";
  }

  value def Temperature {
    unit = "degC";
    quantityKind = "temperature";
  }

  value def DataRate {
    unit = "MB/s";
    quantityKind = "data rate";
  }

  port def ImageOutPort {
    out item frame : ImageFrame;
  }

  port def ImageInPort {
    in item frame : ImageFrame;
  }

  port def DetectionOutPort {
    out item result : DetectionResult;
  }

  port def DetectionInPort {
    in item result : DetectionResult;
  }

  port def DecisionOutPort {
    out item decision : InspectionDecision;
  }

  port def DecisionInPort {
    in item decision : InspectionDecision;
  }

  port def CommandPort {
    in item command : String;
    out item status : String;
  }

  part def IndustrialCamera {
    attribute resolutionWidth : Integer = 1920;
    attribute resolutionHeight : Integer = 1080;
    attribute frameRate : FrameRate = 30;
    attribute powerDraw : Power = 6.5;
    port imageOut : ImageOutPort;
    port control : CommandPort;
  }

  part def EdgeComputeUnit {
    attribute cpuCores : Integer = 8;
    attribute acceleratorTOPS : Real = 16.0;
    attribute memoryGB : Real = 16.0;
    attribute maxPowerDraw : Power = 35.0;
    attribute operatingTemperature : Temperature;
    port imageIn : ImageInPort;
    port detectionOut : DetectionOutPort;
    port control : CommandPort;
  }

  part def OpenSourceObjectDetectionModel {
    attribute modelName : String = "YOLO-family open-source object detector";
    attribute license : String = "open-source";
    attribute inputWidth : Integer = 640;
    attribute inputHeight : Integer = 640;
    attribute confidenceThreshold : Real = 0.70;
    attribute nonMaxSuppressionThreshold : Real = 0.45;
    attribute averageInferenceLatency : Latency = 28.0;
    port imageIn : ImageInPort;
    port detectionOut : DetectionOutPort;
  }

  part def DecisionController {
    attribute minimumAcceptConfidence : Real = 0.85;
    attribute maxAllowedDefects : Integer = 0;
    attribute decisionLatency : Latency = 5.0;
    port detectionIn : DetectionInPort;
    port decisionOut : DecisionOutPort;
    port control : CommandPort;
  }

  part def ConveyorInterface {
    attribute conveyorSpeed_mps : Real = 0.45;
    attribute rejectActuationLatency : Latency = 80.0;
    port decisionIn : DecisionInPort;
    port control : CommandPort;
  }

  part def OperatorConsole {
    attribute displayRefreshRate : FrameRate = 60;
    attribute logDataRate : DataRate = 2.0;
    port decisionIn : DecisionInPort;
    port detectionIn : DetectionInPort;
    port control : CommandPort;
  }

  action def CaptureFrame {
    out item frame : ImageFrame;
  }

  action def PreprocessFrame {
    in item rawFrame : ImageFrame;
    out item normalizedFrame : ImageFrame;
  }

  action def RunOpenSourceInference {
    in item normalizedFrame : ImageFrame;
    out item detection : DetectionResult;
  }

  action def EvaluateInspectionResult {
    in item detection : DetectionResult;
    out item decision : InspectionDecision;
  }

  action def ActuateRejectGate {
    in item decision : InspectionDecision;
  }

  action def LogInspection {
    in item detection : DetectionResult;
    in item decision : InspectionDecision;
  }

  state def InspectionLifecycle {
    state idle;
    state initializing;
    state running;
    state degraded;
    state faulted;
    state stopped;

    entry; then idle;

    transition idle_to_initializing
      first idle
      accept command == "start"
      then initializing;

    transition initializing_to_running
      first initializing
      accept status == "ready"
      then running;

    transition running_to_degraded
      first running
      accept operatingTemperature > 75.0
      then degraded;

    transition degraded_to_running
      first degraded
      accept operatingTemperature <= 65.0
      then running;

    transition running_to_faulted
      first running
      accept status == "camera_lost" or status == "model_error"
      then faulted;

    transition degraded_to_faulted
      first degraded
      accept status == "model_error"
      then faulted;

    transition faulted_to_initializing
      first faulted
      accept command == "reset"
      then initializing;

    transition running_to_stopped
      first running
      accept command == "stop"
      then stopped;

    transition stopped_to_idle
      first stopped
      accept status == "safe"
      then idle;
  }

  part def OpenSourceModelInspectionCell {
    doc /* Primary function: automatically inspect items moving on a conveyor by using an open-source computer-vision object detection model to identify defects, classify product condition, and command accept or reject handling in real time. */

    part camera : IndustrialCamera;
    part compute : EdgeComputeUnit;
    part detector : OpenSourceObjectDetectionModel;
    part controller : DecisionController;
    part conveyor : ConveyorInterface;
    part console : OperatorConsole;

    attribute endToEndLatency : Latency;
    attribute sustainedThroughput_fps : FrameRate;
    attribute totalPowerDraw : Power;

    port operatorCommand : CommandPort;

    connect camera.imageOut to compute.imageIn;
    connect compute.imageIn to detector.imageIn;
    connect detector.detectionOut to compute.detectionOut;
    connect compute.detectionOut to controller.detectionIn;
    connect controller.decisionOut to conveyor.decisionIn;
    connect controller.decisionOut to console.decisionIn;
    connect compute.detectionOut to console.detectionIn;
    connect operatorCommand to console.control;
    connect console.control to camera.control;
    connect console.control to compute.control;
    connect console.control to controller.control;
    connect console.control to conveyor.control;

    perform action CaptureFrame {
      out frame = camera.imageOut.frame;
    }

    perform action PreprocessFrame {
      in rawFrame = camera.imageOut.frame;
      out normalizedFrame = detector.imageIn.frame;
    }

    perform action RunOpenSourceInference {
      in normalizedFrame = detector.imageIn.frame;
      out detection = detector.detectionOut.result;
    }

    perform action EvaluateInspectionResult {
      in detection = compute.detectionOut.result;
      out decision = controller.decisionOut.decision;
    }

    perform action ActuateRejectGate {
      in decision = conveyor.decisionIn.decision;
    }

    perform action LogInspection {
      in detection = console.detectionIn.result;
      in decision = console.decisionIn.decision;
    }

    exhibit state InspectionLifecycle;
  }

  requirement def RealTimeInspectionRequirement {
    doc /* The inspection cell shall produce an accept or reject decision within the allowed conveyor handling window. */
    subject system : OpenSourceModelInspectionCell;
    require constraint {
      system.endToEndLatency <= 120.0
    }
  }

  requirement def ThroughputRequirement {
    doc /* The inspection cell shall process image frames at production-line speed. */
    subject system : OpenSourceModelInspectionCell;
    require constraint {
      system.sustainedThroughput_fps >= 25.0
    }
  }

  requirement def ModelTransparencyRequirement {
    doc /* The object detection capability shall be based on an open-source model with documented training configuration, model weights, and inference parameters available for audit. */
    subject model : OpenSourceObjectDetectionModel;
    require constraint {
      model.license == "open-source"
    }
  }

  requirement def DetectionConfidenceRequirement {
    doc /* A product shall be accepted only when the detected condition confidence meets or exceeds the configured acceptance threshold. */
    subject controller : DecisionController;
    require constraint {
      controller.minimumAcceptConfidence >= 0.85
    }
  }

  requirement def PowerRequirement {
    doc /* The complete inspection cell shall operate within the power budget for an edge-mounted station. */
    subject system : OpenSourceModelInspectionCell;
    require constraint {
      system.totalPowerDraw <= 60.0
    }
  }

  requirement def SafeFailureRequirement {
    doc /* If the camera stream or inference model fails, the cell shall transition to a faulted state and command the conveyor interface to reject or stop affected items. */
    subject system : OpenSourceModelInspectionCell;
  }

  part inspectionCell : OpenSourceModelInspectionCell {
    attribute endToEndLatency : Latency = 113.0;
    attribute sustainedThroughput_fps : FrameRate = 30.0;
    attribute totalPowerDraw : Power = 49.5;
  }

  satisfy RealTimeInspectionRequirement by inspectionCell;
  satisfy ThroughputRequirement by inspectionCell;
  satisfy PowerRequirement by inspectionCell;
  satisfy ModelTransparencyRequirement by inspectionCell.detector;
  satisfy DetectionConfidenceRequirement by inspectionCell.controller;
  satisfy SafeFailureRequirement by inspectionCell;
}