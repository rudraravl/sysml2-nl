package SlurryPumpingSubsystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQPressure::*;
    import ISQTemperature::*;
    import ISQAcceleration::*;
    import ISQMassFraction::*;

    // ---- Value Types ----
    def SlurryDensity :> DensityValue;
    def SolidsContent :> Real { unit 'percent'; }
    def FlowRate :> VolumeFlowRateValue;
    def PumpPressure :> PressureValue;
    def VibrationLevel :> AccelerationValue;
    def TemperatureValue :> TemperatureValue;
    def ValvePosition :> Real { unit 'percent'; }
    def PumpSpeed :> Real { unit 'rev/min'; }

    // ---- Item Types ----
    item def HighDensitySlurry {
        attribute density : SlurryDensity;
        attribute solidsContent : SolidsContent;
        attribute viscosity : Real { unit 'Pa.s'; }
    }

    // ---- Port Definitions ----
    port def SlurryPort {
        out item slurry : HighDensitySlurry;
    }

    port def PressureSignalPort {
        out attribute pressure : PumpPressure;
    }

    port def FlowSignalPort {
        out attribute flowRate : FlowRate;
    }

    port def VibrationSignalPort {
        out attribute vibration : VibrationLevel;
    }

    port def TemperatureSignalPort {
        out attribute temperature : TemperatureValue;
    }

    port def ControlCmdPort {
        in attribute startCmd : Boolean;
        in attribute stopCmd : Boolean;
        in attribute valveCmd : ValvePosition;
    }

    port def StatusPort {
        out attribute state : String;
        out attribute fault : Boolean;
    }

    // ---- Component Definitions ----

    part def SupplyTank {
        port dischargePort : SlurryPort;
        attribute capacity : VolumeValue = 5000 [L];
        attribute currentLevel : VolumeValue;
        action def SupplySlurry {
            out item slurry : HighDensitySlurry;
        }
    }

    part def DischargeTank {
        port inletPort : SlurryPort;
        attribute capacity : VolumeValue = 8000 [L];
        attribute currentLevel : VolumeValue;
        action def ReceiveSlurry {
            in item slurry : HighDensitySlurry;
        }
    }

    part def Pipe {
        port inlet : SlurryPort;
        port outlet : SlurryPort;
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute roughness : Real;
        flow slurryFlow of HighDensitySlurry from inlet.slurry to outlet.slurry;
    }

    part def ControlValve {
        port inlet : SlurryPort;
        port outlet : SlurryPort;
        port control : ControlCmdPort;
        attribute position : ValvePosition = 100 [percent];
        attribute maxPressure : PumpPressure = 100 [bar];
        flow slurryFlow of HighDensitySlurry from inlet.slurry to outlet.slurry;
        action def AdjustValve {
            in cmd : ValvePosition;
            out newPos : ValvePosition;
        }
    }

    part def PressureSensor {
        port measurementPort : SlurryPort;
        port signalPort : PressureSignalPort;
        attribute range : PumpPressure = 100 [bar];
        attribute accuracy : Real = 0.5 [percent];
        action def MeasurePressure {
            in item slurry : HighDensitySlurry;
            out pressure : PumpPressure;
        }
    }

    part def FlowSensor {
        port measurementPort : SlurryPort;
        port signalPort : FlowSignalPort;
        attribute range : FlowRate = 500 [L/min];
        attribute accuracy : Real = 1.0 [percent];
        action def MeasureFlow {
            in item slurry : HighDensitySlurry;
            out flowRate : FlowRate;
        }
    }

    part def VibrationSensor {
        port signalPort : VibrationSignalPort;
        attribute range : VibrationLevel = 50 [m/s^2];
        action def MeasureVibration {
            out vibration : VibrationLevel;
        }
    }

    part def TemperatureSensor {
        port signalPort : TemperatureSignalPort;
        attribute range : TemperatureValue = 150 [degC];
        action def MeasureTemperature {
            out temperature : TemperatureValue;
        }
    }

    part def HighDensitySolidsPump {
        port suctionPort : SlurryPort;
        port dischargePort : SlurryPort;
        port inletPressureSensor : PressureSignalPort;
        port outletPressureSensor : PressureSignalPort;
        port flowSensorInput : FlowSignalPort;
        port vibrationSensorInput : VibrationSignalPort;
        port temperatureSensorInput : TemperatureSignalPort;
        port controlPort : ControlCmdPort;
        port statusPort : StatusPort;

        attribute ratedFlow : FlowRate = 300 [L/min];
        attribute ratedPressure : PumpPressure = 60 [bar];
        attribute ratedSpeed : PumpSpeed = 1450 [rev/min];
        attribute maxTemperature : TemperatureValue = 95 [degC];
        attribute maxVibration : VibrationLevel = 15 [m/s^2];
        attribute maxInletPressure : PumpPressure = 5 [bar];
        attribute maxOutletPressure : PumpPressure = 80 [bar];

        attribute currentSpeed : PumpSpeed;
        attribute currentFlow : FlowRate;
        attribute currentInletPressure : PumpPressure;
        attribute currentOutletPressure : PumpPressure;
        attribute currentVibration : VibrationLevel;
        attribute currentTemperature : TemperatureValue;
        attribute faultDetected : Boolean = false;

        flow slurryFlow of HighDensitySlurry from suctionPort.slurry to dischargePort.slurry;

        action def PressurizeSlurry {
            in item slurry : HighDensitySlurry;
            out item pressurizedSlurry : HighDensitySlurry;
        }

        action def MonitorPumpHealth {
            in vibration : VibrationLevel;
            in temperature : TemperatureValue;
            in inletPressure : PumpPressure;
            in outletPressure : PumpPressure;
            out degraded : Boolean;
            out fault : Boolean;
            
            // Assess vibration
            if vibration > 15 [m/s^2] then { fault := true; }
            else if vibration > 10 [m/s^2] then { degraded := true; }
            else { degraded := false; }
            
            // Assess temperature
            if temperature > 95 [degC] then { fault := true; }
            else if temperature > 80 [degC] then { degraded := true; }
            
            // Assess pressures
            if outletPressure > 80 [bar] then { fault := true; }
            if inletPressure > 5 [bar] then { fault := true; }
        }

        state machine PumpStateMachine {
            state stopped {
                entry action { currentSpeed := 0 [rev/min]; faultDetected := false; }
                transition starting on controlPort.startCmd
                    if controlPort.startCmd == true
                    to starting;
            }

            state starting {
                entry action { currentSpeed := currentSpeed + 50 [rev/min]; }
                do action MonitorPumpHealth;
                transition to operating
                    if currentSpeed >= ratedSpeed;
                transition to faulted
                    if faultDetected == true;
            }

            state operating {
                do action PressurizeSlurry;
                do action MonitorPumpHealth;
                transition to stopped on controlPort.stopCmd
                    if controlPort.stopCmd == true;
                transition to faulted
                    if faultDetected == true;
            }

            state faulted {
                entry action { currentSpeed := 0 [rev/min]; }
                transition to stopped
                    if controlPort.stopCmd == true;
            }
        }
    }

    part def PumpController {
        port pumpControl : ControlCmdPort;
        port pumpStatus : StatusPort;
        port inletPressureInput : PressureSignalPort;
        port outletPressureInput : PressureSignalPort;
        port flowInput : FlowSignalPort;
        port vibrationInput : VibrationSignalPort;
        port temperatureInput : TemperatureSignalPort;

        attribute targetFlow : FlowRate = 250 [L/min];
        attribute minFlow : FlowRate = 200 [L/min];
        attribute maxOutletPressure : PumpPressure = 75 [bar];

        action def EvaluatePerformance {
            in flowRate : FlowRate;
            in outletPressure : PumpPressure;
            in vibration : VibrationLevel;
            in temperature : TemperatureValue;
            out adjustValve : ValvePosition;
            out fault : Boolean;
            
            if flowRate < minFlow then {
                adjustValve := 100 [percent];
            }
            else if flowRate > targetFlow then {
                adjustValve := 80 [percent];
            }
            else {
                adjustValve := 90 [percent];
            }
            
            if outletPressure > maxOutletPressure then { fault := true; }
            if vibration > 15 [m/s^2] then { fault := true; }
            if temperature > 95 [degC] then { fault := true; }
        }
    }

    // ---- Top-level System ----
    part SlurryPumpingSystem {

        part supplyTank : SupplyTank {
            attribute currentLevel := 4500 [L];
        }

        part dischargeTank : DischargeTank {
            attribute currentLevel := 0 [L];
        }

        part suctionPipe : Pipe {
            attribute length := 5 [m];
            attribute diameter := 0.15 [m];
        }

        part suctionControlValve : ControlValve {
            attribute position := 100 [percent];
        }

        part pump : HighDensitySolidsPump;

        part dischargePipe : Pipe {
            attribute length := 3 [m];
            attribute diameter := 0.12 [m];
        }

        part dischargeControlValve : ControlValve {
            attribute position := 100 [percent];
        }

        part deliveryPipe : Pipe {
            attribute length := 20 [m];
            attribute diameter := 0.12 [m];
        }

        part inletPressureSensor : PressureSensor {
            attribute range := 10 [bar];
        }

        part outletPressureSensor : PressureSensor {
            attribute range := 100 [bar];
        }

        part flowSensor : FlowSensor {
            attribute range := 500 [L/min];
        }

        part vibrationSensor : VibrationSensor;

        part temperatureSensor : TemperatureSensor;

        part controller : PumpController;

        // ---- Connections ----
        connection supplyToSuctionPipe : SlurryPort connect supplyTank.dischargePort to suctionPipe.inlet;
        connection suctionPipeToValve : SlurryPort connect suctionPipe.outlet to suctionControlValve.inlet;
        connection valveToPumpSuction : SlurryPort connect suctionControlValve.outlet to pump.suctionPort;
        connection pumpToDischargePipe : SlurryPort connect pump.dischargePort to dischargePipe.inlet;
        connection dischargePipeToValve : SlurryPort connect dischargePipe.outlet to dischargeControlValve.inlet;
        connection valveToDeliveryPipe : SlurryPort connect dischargeControlValve.outlet to deliveryPipe.inlet;
        connection deliveryPipeToTank : SlurryPort connect deliveryPipe.outlet to dischargeTank.inletPort;

        // Sensor connections
        connection inletPressureMeasurement : SlurryPort connect suctionControlValve.outlet to inletPressureSensor.measurementPort;
        connection inletPressureSignal : PressureSignalPort connect inletPressureSensor.signalPort to pump.inletPressureSensor;
        connection inletPressureToController : PressureSignalPort connect inletPressureSensor.signalPort to controller.inletPressureInput;

        connection outletPressureMeasurement : SlurryPort connect dischargePipe.inlet to outletPressureSensor.measurementPort;
        connection outletPressureSignal : PressureSignalPort connect outletPressureSensor.signalPort to pump.outletPressureSensor;
        connection outletPressureToController : PressureSignalPort connect outletPressureSensor.signalPort to controller.outletPressureInput;

        connection flowMeasurement : SlurryPort connect dischargePipe.outlet to flowSensor.measurementPort;
        connection flowSignalToPump : FlowSignalPort connect flowSensor.signalPort to pump.flowSensorInput;
        connection flowSignalToController : FlowSignalPort connect flowSensor.signalPort to controller.flowInput;

        connection vibrationSignalToPump : VibrationSignalPort connect vibrationSensor.signalPort to pump.vibrationSensorInput;
        connection vibrationSignalToController : VibrationSignalPort connect vibrationSensor.signalPort to controller.vibrationInput;

        connection temperatureSignalToPump : TemperatureSignalPort connect temperatureSensor.signalPort to pump.temperatureSensorInput;
        connection temperatureSignalToController : TemperatureSignalPort connect temperatureSensor.signalPort to controller.temperatureInput;

        // Control connections
        connection controllerToPumpControl : ControlCmdPort connect controller.pumpControl to pump.controlPort;
        connection pumpToControllerStatus : StatusPort connect pump.statusPort to controller.pumpStatus;
    }

    // ---- Requirements ----
    package Requirements {
        requirement def MinFlowRateRequirement {
            attribute minFlow : FlowRate = 200 [L/min];
            subject slurrySystem : SlurryPumpingSystem;
            objective {
                doc "The system shall maintain a minimum slurry flow rate of 200 L/min during operating state.";
            }
            assert { slurrySystem.pump.currentFlow >= minFlow }
        }

        requirement def DischargePressureRequirement {
            attribute minPressure : PumpPressure = 40 [bar];
            attribute maxPressure : PumpPressure = 75 [bar];
            subject slurrySystem : SlurryPumpingSystem;
            objective {
                doc "The pump shall achieve a discharge pressure of at least 40 bar and not exceed 75 bar during operation.";
            }
            assert { slurrySystem.pump.currentOutletPressure >= minPressure and slurrySystem.pump.currentOutletPressure <= maxPressure }
        }

        requirement def SolidsContentRequirement {
            attribute minSolids : SolidsContent = 35 [percent];
            attribute maxSolids : SolidsContent = 70 [percent];
            subject slurry : HighDensitySlurry;
            objective {
                doc "The slurry shall contain between 35% and 70% solids content by mass.";
            }
            assert { slurry.solidsContent >= minSolids and slurry.solidsContent <= maxSolids }
        }

        requirement def OverPressurizationSafetyRequirement {
            attribute maxSafePressure : PumpPressure = 80 [bar];
            subject slurrySystem : SlurryPumpingSystem;
            objective {
                doc "The system shall transition to faulted state if outlet pressure exceeds 80 bar to prevent over-pressurization.";
            }
            assert { slurrySystem.pump.currentOutletPressure <= maxSafePressure }
        }

        requirement def VibrationSafetyRequirement {
            attribute maxVibration : VibrationLevel = 15 [m/s^2];
            subject slurrySystem : SlurryPumpingSystem;
            objective {
                doc "The system shall transition to faulted state if pump vibration exceeds 15 m/s^2.";
            }
            assert { slurrySystem.pump.currentVibration <= maxVibration }
        }

        requirement def TemperatureSafetyRequirement {
            attribute maxTemp : TemperatureValue = 95 [degC];
            subject slurrySystem : SlurryPumpingSystem;
            objective {
                doc "The system shall transition to faulted state if pump temperature exceeds 95 degC.";
            }
            assert { slurrySystem.pump.currentTemperature <= maxTemp }
        }

        requirement def StateTransitionRequirement {
            subject slurrySystem : SlurryPumpingSystem;
            objective {
                doc "The system shall support states: stopped, starting, operating, and faulted with defined transitions.";
            }
        }

        requirement def MonitoringRequirement {
            subject slurrySystem : SlurryPumpingSystem;
            objective {
                doc "A monitoring function shall continuously assess pump vibration, temperature, and operating pressures to detect degraded performance or failures.";
            }
        }

        requirement def PumpTypeRequirement {
            subject pump : HighDensitySolidsPump;
            objective {
                doc "The pump shall be a positive displacement type with wear-resistant components suitable for abrasive slurry handling.";
            }
        }

        requirement def SensorPlacementRequirement {
            subject slurrySystem : SlurryPumpingSystem;
            objective {
                doc "Pressure sensors shall be installed at pump inlet and outlet; a flow sensor shall be installed on the discharge side.";
            }
        }

        requirement SlurryFlowRequirement :> MinFlowRateRequirement;
        requirement PressurePerformanceRequirement :> DischargePressureRequirement;
        requirement SlurryCompositionRequirement :> SolidsContentRequirement;
        requirement SafetyOverPressurizationRequirement :> OverPressurizationSafetyRequirement;
        requirement SafetyVibrationRequirement :> VibrationSafetyRequirement;
        requirement SafetyTemperatureRequirement :> TemperatureSafetyRequirement;
        requirement OperationalStatesRequirement :> StateTransitionRequirement;
        requirement HealthMonitoringRequirement :> MonitoringRequirement;
        requirement PumpDesignRequirement :> PumpTypeRequirement;
        requirement InstrumentationRequirement :> SensorPlacementRequirement;
    }
}
