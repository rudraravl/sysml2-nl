package CatalyticBeadSensorSystem {
    import ScalarValues::*;
    import ISQ::*;

    item def CombustibleGas;
    item def SampleGas {
        attribute concentration : Real;
        ref item gas : CombustibleGas;
    }
    item def CalibrationData {
        attribute slope : Real;
        attribute offset : Real;
        attribute baselineResistance : Real;
    }

    attribute def MeasureCommand;
    attribute def CalibrateCommand;
    attribute def ResetCommand;
    attribute def TemperatureStable;
    attribute def FaultDetected;
    attribute def MeasurementComplete;
    attribute def CalibrationComplete;

    port def GasPort {
        in item sample : SampleGas;
    }
    port def DataOutputPort {
        out attribute concentration : Real;
        out attribute status : String;
    }
    port def ElectricalPort {
        attribute resistance : Real;
        attribute voltage : Real;
    }
    port def HeatingControlPort {
        attribute targetTemp :> ISQ::temperature;
    }
    port def PowerPort {
        attribute power :> ISQ::power;
    }
    port def DigitalDataPort {
        attribute value : Integer;
    }
    port def FaultPort {
        out attribute faultActive : Boolean;
    }

    part def Bead {
        attribute resistance : Real;
        attribute temperature :> ISQ::temperature;
        port heatingPort : HeatingControlPort;
        port electricalPort : ElectricalPort;
        port gasPort : GasPort;
    }
    part def ActiveBead :> Bead {
        attribute catalystCoating : String := "PalladiumPlatinum";
        attribute exposedToGas : Boolean := true;
    }
    part def ReferenceBead :> Bead {
        attribute exposedToGas : Boolean := false;
    }

    part def HeatingController {
        attribute targetTemperature :> ISQ::temperature := 500 [K];
        attribute maxTemperature :> ISQ::temperature := 550 [K];
        port powerIn : PowerPort;
        port activeBeadControl : HeatingControlPort;
        port referenceBeadControl : HeatingControlPort;
        action regulateTemperature;
    }

    part def WheatstoneBridge {
        attribute excitationVoltage : Real := 5.0;
        attribute outputVoltage : Real;
        port activeBeadInput : ElectricalPort;
        port referenceBeadInput : ElectricalPort;
        port outputPort : ElectricalPort;
        action measureDifferential;
    }

    part def SignalAmplifier {
        attribute gain : Real := 100.0;
        port inputPort : ElectricalPort;
        port outputPort : ElectricalPort;
        action amplify;
    }

    part def AnalogDigitalConverter {
        attribute resolutionBits : Integer := 16;
        attribute fullScaleVoltage : Real := 5.0;
        port inputPort : ElectricalPort;
        port outputPort : DigitalDataPort;
        action convert;
    }

    part def SignalProcessor {
        attribute calibrationSlope : Real := 1.0;
        attribute calibrationOffset : Real := 0.0;
        attribute concentrationReading : Real;
        ref item calibration : CalibrationData;
        port inputPort : DigitalDataPort;
        port dataOut : DataOutputPort;
        port faultOut : FaultPort;
        action calculateConcentration;
        action runDiagnostics;
    }

    part def CatalyticBeadSensor {
        attribute operatingTemperature :> ISQ::temperature := 500 [K];
        attribute gasConcentration : Real;
        attribute faultActive : Boolean := false;
        port gasInlet : GasPort;
        port dataOut : DataOutputPort;
        port faultOut : FaultPort;
        port powerIn : PowerPort;

        part heatingController : HeatingController;
        part activeBead : ActiveBead;
        part referenceBead : ReferenceBead;
        part wheatstoneBridge : WheatstoneBridge;
        part signalAmplifier : SignalAmplifier;
        part adc : AnalogDigitalConverter;
        part signalProcessor : SignalProcessor;

        action initializeBeads;
        action performMeasurement {
            perform wheatstoneBridge.measureDifferential;
            perform signalAmplifier.amplify;
            perform adc.convert;
            perform signalProcessor.calculateConcentration;
            assign gasConcentration := signalProcessor.concentrationReading;
        }
        action performCalibration {
            assign signalProcessor.calibrationSlope := 1.0;
            assign signalProcessor.calibrationOffset := 0.0;
        }
        action signalFault {
            assign faultActive := true;
        }

        connect powerIn to heatingController.powerIn;
        connect heatingController.activeBeadControl to activeBead.heatingPort;
        connect heatingController.referenceBeadControl to referenceBead.heatingPort;
        connect gasInlet to activeBead.gasPort;
        connect activeBead.electricalPort to wheatstoneBridge.activeBeadInput;
        connect referenceBead.electricalPort to wheatstoneBridge.referenceBeadInput;
        connect wheatstoneBridge.outputPort to signalAmplifier.inputPort;
        connect signalAmplifier.outputPort to adc.inputPort;
        connect adc.outputPort to signalProcessor.inputPort;
        connect signalProcessor.dataOut to dataOut;
        connect signalProcessor.faultOut to faultOut;

        exhibit state sensorStates {
            entry; then warmup;

            state warmup {
                do heatingController.regulateTemperature;
            }
            transition warmup_to_ready
                first warmup
                accept TemperatureStable
                then ready;

            state ready;
            transition ready_to_measuring
                first ready
                accept MeasureCommand
                then measuring;
            transition ready_to_calibration
                first ready
                accept CalibrateCommand
                then calibration;

            state measuring {
                entry performMeasurement;
            }
            transition measuring_to_ready
                first measuring
                accept MeasurementComplete
                then ready;

            state calibration {
                entry performCalibration;
            }
            transition calibration_to_ready
                first calibration
                accept CalibrationComplete
                then ready;

            state fault {
                entry signalFault;
            }
            transition warmup_to_fault
                first warmup
                accept FaultDetected
                then fault;
            transition ready_to_fault
                first ready
                accept FaultDetected
                then fault;
            transition measuring_to_fault
                first measuring
                accept FaultDetected
                then fault;
            transition calibration_to_fault
                first calibration
                accept FaultDetected
                then fault;
            transition fault_to_warmup
                first fault
                accept ResetCommand
                then warmup;
        }
    }

    requirement def AccuracyRequirement {
        attribute maxErrorPercent : Real := 5.0;
        subject sensor : CatalyticBeadSensor;
        doc { The sensor shall measure gas concentration within plus or minus 5 percent of the true value. }
    }
    requirement def FailSafeRequirement {
        subject sensor : CatalyticBeadSensor;
        doc { The sensor shall enter a fault state when a malfunction is detected to ensure fail-safe operation in hazardous environments. }
    }
    requirement def OperatingTempRequirement {
        attribute targetTemp :> ISQ::temperature := 500 [K];
        attribute tolerance :> ISQ::temperature := 10 [K];
        subject sensor : CatalyticBeadSensor;
        doc { The catalytic beads shall be maintained at 500 degrees Celsius plus or minus 10 degrees during operation. }
    }
    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : Real := 2.0;
        subject sensor : CatalyticBeadSensor;
        doc { The sensor shall produce a valid reading within 2 seconds of receiving a measure command. }
    }

    part catalyticSensor : CatalyticBeadSensor;

    requirement accReq : AccuracyRequirement;
    requirement failSafeReq : FailSafeRequirement;
    requirement opTempReq : OperatingTempRequirement;
    requirement responseTimeReq : ResponseTimeRequirement;
}
