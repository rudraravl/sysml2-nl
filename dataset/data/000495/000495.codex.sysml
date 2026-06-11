package RetinalImplantSystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Voltage : Real {
        unit = "V";
    }

    attribute def Current : Real {
        unit = "uA";
    }

    attribute def Power : Real {
        unit = "mW";
    }

    attribute def Frequency : Real {
        unit = "Hz";
    }

    attribute def Luminance : Real {
        unit = "cd/m^2";
    }

    attribute def Temperature : Real {
        unit = "degC";
    }

    attribute def TimeDuration : Real {
        unit = "ms";
    }

    attribute def PixelCount : Integer;

    attribute def ElectrodeCount : Integer;

    item def LightField {
        attribute luminance : Luminance;
        attribute frameRate : Frequency;
        attribute horizontalPixels : PixelCount;
        attribute verticalPixels : PixelCount;
    }

    item def ImageFrame {
        attribute frameRate : Frequency;
        attribute width : PixelCount;
        attribute height : PixelCount;
        attribute exposureTime : TimeDuration;
    }

    item def EncodedVisualPattern {
        attribute patternRate : Frequency;
        attribute activeChannelCount : ElectrodeCount;
        attribute pulseWidth : TimeDuration;
        attribute maxAmplitude : Current;
    }

    item def StimulationPulse {
        attribute amplitude : Current;
        attribute pulseWidth : TimeDuration;
        attribute interPhaseGap : TimeDuration;
        attribute repetitionRate : Frequency;
        attribute isChargeBalanced : Boolean;
    }

    item def NeuralResponse {
        attribute perceivedBrightness : Real;
        attribute stimulatedRegionCount : ElectrodeCount;
        attribute responseLatency : TimeDuration;
    }

    item def TelemetryPacket {
        attribute implantTemperature : Temperature;
        attribute supplyVoltage : Voltage;
        attribute deliveredPower : Power;
        attribute faultPresent : Boolean;
    }

    port def OpticalInputPort {
        in item light : LightField;
    }

    port def ImagePort {
        out item frame : ImageFrame;
    }

    port def PatternPort {
        out item pattern : EncodedVisualPattern;
    }

    port def StimulationPort {
        out item pulse : StimulationPulse;
    }

    port def NeuralInterfacePort {
        out item stimulation : StimulationPulse;
        in item response : NeuralResponse;
    }

    port def PowerPort {
        in attribute voltage : Voltage;
        out attribute loadPower : Power;
    }

    port def TelemetryPort {
        out item telemetry : TelemetryPacket;
        in item configuration : EncodedVisualPattern;
    }

    part def ExternalVisualProcessor {
        port opticalInput : OpticalInputPort;
        port imageOutput : ImagePort;
        port powerInput : PowerPort;
        port telemetryLink : TelemetryPort;

        attribute captureFrameRate : Frequency = 30.0;
        attribute cameraHorizontalPixels : PixelCount = 640;
        attribute cameraVerticalPixels : PixelCount = 480;
        attribute processorPower : Power = 350.0;

        action captureScene {
            in item sceneLight : LightField;
            out item capturedFrame : ImageFrame;
        }

        action enhanceContrast {
            in item rawFrame : ImageFrame;
            out item enhancedFrame : ImageFrame;
        }
    }

    part def WirelessPowerAndDataLink {
        port externalPower : PowerPort;
        port implantPower : PowerPort;
        port externalTelemetry : TelemetryPort;
        port implantTelemetry : TelemetryPort;

        attribute carrierFrequency : Frequency = 13000000.0;
        attribute nominalTransferPower : Power = 25.0;
        attribute regulatedImplantVoltage : Voltage = 3.3;

        action regulatePower {
            in attribute receivedVoltage : Voltage;
            out attribute regulatedVoltage : Voltage;
        }

        action transferTelemetry {
            in item upstreamStatus : TelemetryPacket;
            in item downstreamConfiguration : EncodedVisualPattern;
        }
    }

    part def ImplantController {
        port imageInput : ImagePort;
        port patternOutput : PatternPort;
        port powerInput : PowerPort;
        port telemetry : TelemetryPort;

        attribute stimulationFrameRate : Frequency = 30.0;
        attribute maximumLatency : TimeDuration = 100.0;
        attribute controllerPower : Power = 4.0;

        action mapImageToPhosphenePattern {
            in item frame : ImageFrame;
            out item pattern : EncodedVisualPattern;
        }

        action monitorImplantHealth {
            in attribute temperature : Temperature;
            in attribute supplyVoltage : Voltage;
            out item status : TelemetryPacket;
        }

        state behavior controllerStateMachine {
            state off;
            state initializing;
            state ready;
            state stimulating;
            state fault;

            entry; then off;

            transition off_to_initializing
                first off
                accept PowerApplied
                then initializing;

            transition initializing_to_ready
                first initializing
                accept SelfTestPassed
                then ready;

            transition ready_to_stimulating
                first ready
                accept ValidImageFrameReceived
                then stimulating;

            transition stimulating_to_ready
                first stimulating
                accept PatternDelivered
                then ready;

            transition any_to_fault
                first off, initializing, ready, stimulating
                accept FaultDetected
                then fault;

            transition fault_to_initializing
                first fault
                accept ResetCommanded
                then initializing;
        }
    }

    part def ElectrodeDriverArray {
        port patternInput : PatternPort;
        port stimulationOutput : StimulationPort;
        port powerInput : PowerPort;

        attribute electrodeCount : ElectrodeCount = 1024;
        attribute maximumPulseAmplitude : Current = 800.0;
        attribute minimumPulseWidth : TimeDuration = 0.05;
        attribute maximumPulseWidth : TimeDuration = 2.0;
        attribute driverPower : Power = 8.0;

        action generateChargeBalancedPulse {
            in item pattern : EncodedVisualPattern;
            out item pulse : StimulationPulse;
        }

        action disableUnsafeChannels {
            in item requestedPulse : StimulationPulse;
            out item limitedPulse : StimulationPulse;
        }
    }

    part def RetinalElectrodeArray {
        port stimulationInput : StimulationPort;
        port neuralInterface : NeuralInterfacePort;

        attribute electrodeCount : ElectrodeCount = 1024;
        attribute electrodePitch : Real = 60.0;
        attribute arrayDiameter : Real = 6.0;
        attribute tissueContactImpedance : Real = 25.0;

        action deliverCurrentToRetina {
            in item pulse : StimulationPulse;
            out item response : NeuralResponse;
        }
    }

    part def RetinalImplant {
        port imageInput : ImagePort;
        port powerInput : PowerPort;
        port telemetry : TelemetryPort;
        port neuralInterface : NeuralInterfacePort;

        part controller : ImplantController;
        part driverArray : ElectrodeDriverArray;
        part electrodeArray : RetinalElectrodeArray;

        attribute implantMass : Real = 2.7;
        attribute maximumSurfaceTemperature : Temperature = 39.0;
        attribute nominalImplantPower : Power = 12.0;

        connect imageInput to controller.imageInput;
        connect powerInput to controller.powerInput;
        connect powerInput to driverArray.powerInput;
        connect telemetry to controller.telemetry;
        connect controller.patternOutput to driverArray.patternInput;
        connect driverArray.stimulationOutput to electrodeArray.stimulationInput;
        connect electrodeArray.neuralInterface to neuralInterface;
    }

    part def PatientRetina {
        port neuralInterface : NeuralInterfacePort;

        attribute viableGanglionCellRegions : ElectrodeCount = 850;
        attribute maximumSafeAverageCurrent : Current = 100.0;

        action transduceElectricalPattern {
            in item stimulation : StimulationPulse;
            out item neuralResponse : NeuralResponse;
        }
    }

    part def RetinalProsthesisSystem {
        part visualProcessor : ExternalVisualProcessor;
        part wirelessLink : WirelessPowerAndDataLink;
        part implant : RetinalImplant;
        part retina : PatientRetina;

        port sceneInput : OpticalInputPort;
        port userPowerInput : PowerPort;
        port clinicianTelemetry : TelemetryPort;

        attribute endToEndLatency : TimeDuration;
        attribute restoredVisualFieldDegrees : Real = 20.0;
        attribute nominalSystemPower : Power = 375.0;

        connect sceneInput to visualProcessor.opticalInput;
        connect userPowerInput to visualProcessor.powerInput;
        connect userPowerInput to wirelessLink.externalPower;
        connect visualProcessor.imageOutput to implant.imageInput;
        connect visualProcessor.telemetryLink to wirelessLink.externalTelemetry;
        connect clinicianTelemetry to wirelessLink.externalTelemetry;
        connect wirelessLink.implantPower to implant.powerInput;
        connect wirelessLink.implantTelemetry to implant.telemetry;
        connect implant.neuralInterface to retina.neuralInterface;

        action provideArtificialVision {
            in item ambientLight : LightField;
            out item retinalResponse : NeuralResponse;

            first start;
            then capture by visualProcessor.captureScene;
            then enhance by visualProcessor.enhanceContrast;
            then encode by implant.controller.mapImageToPhosphenePattern;
            then stimulate by implant.driverArray.generateChargeBalancedPulse;
            then deliver by implant.electrodeArray.deliverCurrentToRetina;
            then done;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The retinal implant system shall convert visual light from the environment into safe, spatially patterned electrical stimulation of surviving retinal neurons to provide the user with artificial visual perception. */

        subject system : RetinalProsthesisSystem;

        require constraint {
            system.endToEndLatency <= 100.0
        }
    }

    requirement def SafetyTemperatureRequirement {
        subject implant : RetinalImplant;

        require constraint {
            implant.maximumSurfaceTemperature <= 39.0
        }
    }

    requirement def ChargeBalanceRequirement {
        subject pulse : StimulationPulse;

        require constraint {
            pulse.isChargeBalanced == true
        }
    }

    requirement def ElectrodeResolutionRequirement {
        subject implant : RetinalImplant;

        require constraint {
            implant.electrodeArray.electrodeCount >= 1000
        }
    }

    requirement def PowerRequirement {
        subject implant : RetinalImplant;

        require constraint {
            implant.nominalImplantPower <= 15.0
        }
    }

    requirement def VisualFieldRequirement {
        subject system : RetinalProsthesisSystem;

        require constraint {
            system.restoredVisualFieldDegrees >= 20.0
        }
    }

    satisfy PrimaryFunctionRequirement by RetinalProsthesisSystem::provideArtificialVision;
    satisfy SafetyTemperatureRequirement by RetinalImplant;
    satisfy ElectrodeResolutionRequirement by RetinalImplant;
    satisfy PowerRequirement by RetinalImplant;
    satisfy VisualFieldRequirement by RetinalProsthesisSystem;
}