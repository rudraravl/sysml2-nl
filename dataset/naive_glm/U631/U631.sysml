package CatalyticBeadSensorSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit degC;
    unit V;
    unit Ohm;
    unit ppm;
    unit A;
    unit W;
    unit OhmPerDegC;

    // ===== Value Types =====
    value def TemperatureValue :> Real { unit degC; }
    value def VoltageValue :> Real { unit V; }
    value def ResistanceValue :> Real { unit Ohm; }
    value def ConcentrationValue :> Real { unit ppm; }
    value def CurrentValue :> Real { unit A; }
    value def PowerValue :> Real { unit W; }
    value def DigitalValue :> Integer;
    value def TemperatureCoeff :> Real { unit OhmPerDegC; }

    // ===== Items =====
    item def CombustibleGas;
    item def Air;

    item def SampleGas {
        :>> combustibleGas : CombustibleGas[0..*];
        :>> air : Air[0..*];
    }

    item def CalibrationData {
        :>> slope : Real;
        :>> offset : Real;
    }

    item def MeasurementResult {
        :>> concentration : ConcentrationValue;
        :>> timestamp : String;
        :>> status : String;
    }

    // ===== Requirements =====
    requirement def DetectCombustibleGas {
        subject sensor : CatalyticBeadSensor;
        objective {
            doc "The sensor shall detect and measure the concentration of combustible gases in the environment using catalytic oxidation.";
        }
    }

    requirement def MaintainOperatingTemperature {
        subject controller : HeatingController;
        objective {
            doc "The heating controller shall maintain both beads at approximately 500 degC for catalytic reaction.";
            require controller.targetTemperature == 500 [degC];
        }
    }

    requirement def WarmupPhase {
        subject sensor : CatalyticBeadSensor;
        objective {
            doc "Upon power-up, the sensor shall enter a warmup phase to bring beads to operating temperature.";
        }
    }

    requirement def FaultSafeOperation {
        subject sensor : CatalyticBeadSensor;
        objective {
            doc "The sensor shall enter a fault state upon detection of a malfunction, ensuring fail-safe operation in hazardous environments.";
        }
    }

    requirement def MeasurementAccuracy {
        subject sensor : CatalyticBeadSensor;
        objective {
            doc "The sensor shall calculate gas concentration using calibration data and the amplified Wheatstone bridge output.";
        }
    }

    requirement def DataOutputRequirement {
        subject sensor : CatalyticBeadSensor;
        objective {
            doc "The sensor shall output final measurement data through a dedicated data port.";
        }
    }

    requirement def DifferentialCompensation {
        subject sensor : CatalyticBeadSensor;
        objective {
            doc "The differential bead setup shall cancel out ambient temperature effects so the signal reflects only gas presence.";
        }
    }

    // ===== Port Definitions =====
    port def GasInletPort {
        in item sampleGas : SampleGas;
    }

    port def DataOutputPort {
        out item measurement : MeasurementResult;
    }

    port def AnalogSignalPort {
        out attribute voltage : VoltageValue;
    }

    port def DigitalSignalPort {
        out attribute digitalValue : DigitalValue;
    }

    port def PowerPort {
        in attribute supplyVoltage : VoltageValue;
        in attribute supplyCurrent : CurrentValue;
    }

    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }

    port def BeadHeatingPort {
        in attribute heatingPower : PowerValue;
        out attribute beadTemperature : TemperatureValue;
    }

    port def BeadMeasurementPort {
        out attribute resistance : ResistanceValue;
    }

    port def GasExposurePort {
        in item gas : SampleGas;
    }

    port def HeatingControlPort {
        out attribute heatingPower : PowerValue;
        in attribute beadTemperature : TemperatureValue;
    }

    // ===== Part Definitions =====

    part def CatalyticBead {
        attribute nominalResistance : ResistanceValue = 10 [Ohm];
        attribute temperatureCoefficient : TemperatureCoeff = 0.0039 [OhmPerDegC];
        attribute currentTemperature : TemperatureValue = 25 [degC];
        attribute currentResistance : ResistanceValue = 10 [Ohm];

        port heating : BeadHeatingPort;
        port measurement : BeadMeasurementPort;

        action def UpdateResistance {
            in temp : TemperatureValue;
            in nominalR : ResistanceValue;
            in coeff : TemperatureCoeff;
            out resistance : ResistanceValue;
        }
    }

    part def ActiveBead :> CatalyticBead {
        attribute catalystCoated : Boolean = true;
        attribute exposedToGas : Boolean = true;
        attribute reactionHeat : PowerValue = 0 [W];

        port gasExposure : GasExposurePort;

        action def CatalyticOxidation {
            in item gas : CombustibleGas;
            in beadTemp : TemperatureValue;
            out heatReleased : PowerValue;
        }
    }

    part def ReferenceBead :> CatalyticBead {
        attribute sealed : Boolean = true;
        attribute nonReactive : Boolean = true;
    }

    part def HeatingController {
        attribute targetTemperature : TemperatureValue = 500 [degC];
        attribute tolerance : TemperatureValue = 5 [degC];
        attribute currentPower : PowerValue = 0 [W];
        attribute isStable : Boolean = false;
        attribute maxSafeTemperature : TemperatureValue = 600 [degC];

        port heatingControl : HeatingControlPort;
        port power : PowerPort;

        action def RegulateTemperature {
            in measuredTemp : TemperatureValue;
            in targetTemp : TemperatureValue;
            in tol : TemperatureValue;
            out heatingPower : PowerValue;
            out stable : Boolean;
        }

        action def CheckOverTemperature {
            in measuredTemp : TemperatureValue;
            in maxSafe : TemperatureValue;
            out fault : Boolean;
        }
    }

    part def WheatstoneBridge {
        attribute supplyVoltage : VoltageValue = 5 [V];
        attribute outputVoltage : VoltageValue = 0 [V];
        attribute r1 : ResistanceValue = 10 [Ohm];
        attribute r2 : ResistanceValue = 10 [Ohm];
        attribute maxOutputVoltage : VoltageValue = 10 [V];

        port activeBeadConn : ~BeadMeasurementPort;
        port referenceBeadConn : ~BeadMeasurementPort;
        port bridgeOutput : AnalogSignalPort;
        port power : PowerPort;

        action def CalculateBridgeOutput {
            in rActive : ResistanceValue;
            in rReference : ResistanceValue;
            in supply : VoltageValue;
            out voltage : VoltageValue;
        }
    }

    part def SignalAmplifier {
        attribute gain : Real = 100;
        attribute amplifiedVoltage : VoltageValue = 0 [V];

        port amplifierInput : ~AnalogSignalPort;
        port amplifierOutput : AnalogSignalPort;
        port power : PowerPort;

        action def Amplify {
            in inputVoltage : VoltageValue;
            in amplifierGain : Real;
            out outputVoltage : VoltageValue;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolution : Integer = 16;
        attribute samplingRate : Real = 1000;
        attribute digitalOutput : DigitalValue = 0;

        port adcInput : ~AnalogSignalPort;
        port adcOutput : DigitalSignalPort;
        port power : PowerPort;

        action def Convert {
            in analogVoltage : VoltageValue;
            in bits : Integer;
            out digitalValue : DigitalValue;
        }
    }

    part def SignalProcessor {
        attribute calibrationData : CalibrationData;
        attribute calculatedConcentration : ConcentrationValue = 0 [ppm];
        attribute measurementStatus : String = "idle";

        port processorInput : ~DigitalSignalPort;
        port processorOutput : DataOutputPort;
        port control : ControlPort;
        port power : PowerPort;

        action def CalculateConcentration {
            in digitalValue : DigitalValue;
            in calibration : CalibrationData;
            out concentration : ConcentrationValue;
        }

        action def UpdateCalibration {
            in knownConcentration : ConcentrationValue;
            in measuredDigital : DigitalValue;
            out updatedCalibration : CalibrationData;
        }
    }

    // ===== Top-Level Sensor =====
    part def CatalyticBeadSensor {
        satisfy DetectCombustibleGas;
        satisfy WarmupPhase;
        satisfy FaultSafeOperation;
        satisfy MeasurementAccuracy;
        satisfy DataOutputRequirement;
        satisfy DifferentialCompensation;

        attribute powerOn : Boolean = false;
        attribute faultDetected : Boolean = false;

        port gasInlet : GasInletPort;
        port dataOutput : DataOutputPort;
        port power : PowerPort;
        port control : ControlPort;

        part activeBead : ActiveBead {
            attribute nominalResistance = 10 [Ohm];
        }

        part referenceBead : ReferenceBead {
            attribute nominalResistance = 10 [Ohm];
        }

        part heatingController : HeatingController {
            satisfy MaintainOperatingTemperature;
        }

        part wheatstoneBridge : WheatstoneBridge;
        part signalAmplifier : SignalAmplifier;
        part adc : AnalogToDigitalConverter;
        part signalProcessor : SignalProcessor;

        // Connections - Gas path
        connection gasToActiveBead from gasInlet to activeBead.gasExposure;

        // Connections - Bead measurement to bridge
        connection activeBeadToBridge from activeBead.measurement to wheatstoneBridge.activeBeadConn;
        connection referenceBeadToBridge from referenceBead.measurement to wheatstoneBridge.referenceBeadConn;

        // Connections - Heating control to beads
        connection heatingToActiveBead from heatingController.heatingControl to activeBead.heating;
        connection heatingToReferenceBead from heatingController.heatingControl to referenceBead.heating;

        // Connections - Signal chain
        connection bridgeToAmplifier from wheatstoneBridge.bridgeOutput to signalAmplifier.amplifierInput;
        connection amplifierToADC from signalAmplifier.amplifierOutput to adc.adcInput;
        connection adcToProcessor from adc.adcOutput to signalProcessor.processorInput;
        connection processorToDataPort from signalProcessor.processorOutput to dataOutput;

        // Connections - Power distribution
        connection powerToController from power to heatingController.power;
        connection powerToAmplifier from power to signalAmplifier.power;
        connection powerToADC from power to adc.power;
        connection powerToProcessor from power to signalProcessor.power;

        // Connections - Control
        connection controlToProcessor from control to signalProcessor.control;

        // State Machine
        state sensorStateMachine {
            entry action { /* Initialize all sensor subsystems */ }

            state Off {
                entry action { /* Sensor powered off, all subsystems inactive */ }
            }

            state Warmup {
                entry action {
                    /* Activate heating controller */
                    /* Begin bringing beads to 500 degC operating temperature */
                }
                do action {
                    /* Monitor bead temperatures via heating ports */
                    /* Check temperature stability against tolerance */
                }
            }

            state Ready {
                entry action {
                    /* Beads at operating temperature */
                    /* Signal ready status on control port */
                }
                do action {
                    /* Wait for measurement or calibration command */
                }
            }

            state Measuring {
                entry action {
                    /* Begin sensing cycle */
                }
                do action {
                    /* Perform catalytic oxidation on active bead */
                    /* Measure Wheatstone bridge output voltage */
                    /* Amplify signal */
                    /* Convert to digital via ADC */
                    /* Calculate concentration using calibration data */
                    /* Output result through data port */
                }
            }

            state Calibration {
                entry action {
                    /* Enter calibration mode */
                }
                do action {
                    /* Apply known gas concentration */
                    /* Measure bridge response */
                    /* Update calibration data in signal processor */
                }
            }

            state Fault {
                entry action {
                    /* Set fault status on control port */
                    /* Ensure fail-safe operation */
                    /* Disable heating if over-temperature */
                }
                do action {
                    /* Maintain safe state */
                    /* Await shutdown command */
                }
            }

            transition from Off to Warmup when powerOn == true;
            transition from Warmup to Ready when heatingController.isStable == true;
            transition from Ready to Measuring when control.command == "measure";
            transition from Measuring to Ready when signalProcessor.measurementStatus == "complete";
            transition from Ready to Calibration when control.command == "calibrate";
            transition from Calibration to Ready when control.command == "done";
            transition from Warmup to Fault when heatingController.heatingControl.beadTemperature > heatingController.maxSafeTemperature;
            transition from Ready to Fault when wheatstoneBridge.outputVoltage > wheatstoneBridge.maxOutputVoltage;
            transition from Measuring to Fault when wheatstoneBridge.outputVoltage > wheatstoneBridge.maxOutputVoltage;
            transition from Calibration to Fault when wheatstoneBridge.outputVoltage > wheatstoneBridge.maxOutputVoltage;
            transition from Fault to Off when control.command == "shutdown";
        }

        // Sensing Cycle Action
        action def SensingCycle {
            action admitGas {
                in item gas : SampleGas;
                out item combustible : CombustibleGas;
            }
            action catalyze {
                in item gas : CombustibleGas;
                in temp : TemperatureValue;
                out heat : PowerValue;
            }
            action measureResistance {
                in heat : PowerValue;
                in ambientTemp : TemperatureValue;
                out rActive : ResistanceValue;
                out rReference : ResistanceValue;
            }
            action computeBridgeVoltage {
                in rActive : ResistanceValue;
                in rReference : ResistanceValue;
                out voltage : VoltageValue;
            }
            action amplify {
                in voltage : VoltageValue;
                out amplified : VoltageValue;
            }
            action digitize {
                in voltage : VoltageValue;
                out digital : DigitalValue;
            }
            action computeConcentration {
                in digital : DigitalValue;
                in calibration : CalibrationData;
                out concentration : ConcentrationValue;
            }
            action emitResult {
                in concentration : ConcentrationValue;
                out item result : MeasurementResult;
            }

            flow from admitGas.combustible to catalyze.gas;
            flow from catalyze.heat to measureResistance.heat;
            flow from measureResistance.rActive to computeBridgeVoltage.rActive;
            flow from measureResistance.rReference to computeBridgeVoltage.rReference;
            flow from computeBridgeVoltage.voltage to amplify.voltage;
            flow from amplify.amplified to digitize.voltage;
            flow from digitize.digital to computeConcentration.digital;
            flow from computeConcentration.concentration to emitResult.concentration;
        }
    }
}
