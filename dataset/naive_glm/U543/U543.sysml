package IndustrialFluidTransferSystem {

    // ---- Value Types with Units ----

    package Units {
        import ISQ::*;
        import ISQBase::*;
        import ISQSpaceTime::*;
        import ISQThermodynamics::*;

        value type PressureValue :> Real { unit 'Pa'; }
        value type PressureValueBar :> Real { unit 'bar'; }
        value type TemperatureValue :> Real { unit 'K'; }
        value type TemperatureValueCelsius :> Real { unit 'degC'; }
        value type FlowRateValue :> Real { unit 'm3/s'; }
        value type FlowRateValueLpm :> Real { unit 'L/min'; }
        value type FrequencyValue :> Real { unit 'Hz'; }
        value type RotationalSpeedValue :> Real { unit 'rev/min'; }
        value type VoltageValue :> Real { unit 'V'; }
        value type CurrentValue :> Real { unit 'A'; }
        value type PowerValue :> Real { unit 'W'; }
        value type TorqueValue :> Real { unit 'N*m'; }
        value type ViscosityValue :> Real { unit 'Pa*s'; }
        value type DurationValue :> Real { unit 's'; }
    }

    // ---- Item Types ----

    item def IndustrialFluid {
        attribute viscosity : Units::ViscosityValue;
        attribute density : Real;
        attribute hasSolids : Boolean;
    }

    item def ElectricalPower {
        attribute frequency : Units::FrequencyValue;
        attribute voltage : Units::VoltageValue;
        attribute current : Units::CurrentValue;
        attribute phaseCount : Integer;
    }

    item def ControlSignal {
        attribute targetFlowRate : Units::FlowRateValueLpm;
        attribute command : String;
    }

    item def SensorReading {
        attribute value : Real;
        attribute unit : String;
        attribute timestamp : Real;
    }

    // ---- Port Definitions ----

    port def FluidPort {
        in item fluid : IndustrialFluid;
        out item fluidOut : IndustrialFluid;
    }

    port def SuctionFluidPort {
        in item suctionFluid : IndustrialFluid;
        attribute pressure : Units::PressureValue;
    }

    port def DischargeFluidPort {
        out item dischargeFluid : IndustrialFluid;
        attribute pressure : Units::PressureValue;
    }

    port def ElectricalPowerPort {
        in item power : ElectricalPower;
    }

    port def ControlPort {
        in item command : ControlSignal;
        out item feedback : SensorReading;
    }

    port def MechanicalDrivePort {
        out attribute rotationalSpeed : Units::RotationalSpeedValue;
        out attribute torque : Units::TorqueValue;
    }

    port def SensorOutputPort {
        out item reading : SensorReading;
    }

    // ---- Parts ----

    part def SupplyReservoir {
        port fluidOut : FluidPort;
        attribute capacity : Real;
        attribute fillLevel : Real;
        attribute fluid : IndustrialFluid;
    }

    part def DischargeVessel {
        port fluidIn : FluidPort;
        attribute capacity : Real;
        attribute fillLevel : Real;
        attribute fluid : IndustrialFluid;
    }

    part def SuctionPressureSensor {
        port fluidIn : SuctionFluidPort;
        port output : SensorOutputPort;
        attribute measuredPressure : Units::PressureValue;
        attribute accuracy : Real;
    }

    part def SuctionTemperatureSensor {
        port fluidIn : SuctionFluidPort;
        port output : SensorOutputPort;
        attribute measuredTemperature : Units::TemperatureValueCelsius;
        attribute accuracy : Real;
    }

    part def DischargePressureSensor {
        port fluidIn : DischargeFluidPort;
        port output : SensorOutputPort;
        attribute measuredPressure : Units::PressureValue;
        attribute accuracy : Real;
    }

    part def DischargeTemperatureSensor {
        port fluidIn : DischargeFluidPort;
        port output : SensorOutputPort;
        attribute measuredTemperature : Units::TemperatureValueCelsius;
        attribute accuracy : Real;
    }

    part def FlowMeter {
        port fluidIn : DischargeFluidPort;
        port fluidOut : DischargeFluidPort;
        port output : SensorOutputPort;
        attribute measuredFlowRate : Units::FlowRateValueLpm;
        attribute accuracy : Real;
    }

    part def Rotor {
        attribute material : String;
        attribute helixGeometry : String;
        attribute length : Real;
        attribute diameter : Real;
    }

    part def Stator {
        attribute material : String;
        attribute elastomerType : String;
        attribute doubleHelixGeometry : String;
        attribute length : Real;
    }

    part def Driveshaft {
        attribute material : String;
        attribute diameter : Real;
        attribute length : Real;
        attribute maxTorque : Units::TorqueValue;
    }

    part def MechanicalSeal {
        attribute type : String;
        attribute maxPressure : Units::PressureValue;
        attribute maxTemperature : Units::TemperatureValueCelsius;
    }

    part def ProgressingCavityPump {
        port suctionPort : SuctionFluidPort;
        port dischargePort : DischargeFluidPort;
        port driveInput : MechanicalDrivePort;

        part rotor : Rotor {
            attribute material = "Stainless Steel";
            attribute helixGeometry = "SingleHelix";
        }

        part stator : Stator {
            attribute material = "Nitrile Rubber";
            attribute elastomerType = "NBR";
            attribute doubleHelixGeometry = "DoubleHelix";
        }

        part driveshaft : Driveshaft {
            attribute material = "Stainless Steel 316L";
        }

        part suctionSeal : MechanicalSeal {
            attribute type = "MechanicalFaceSeal";
        }

        part dischargeSeal : MechanicalSeal {
            attribute type = "MechanicalFaceSeal";
        }

        attribute nominalFlowRate : Units::FlowRateValueLpm = 150;
        attribute maxPressure : Units::PressureValueBar = 12;
        attribute displacementPerRev : Real;

        action def PumpFluid {
            in item inletFluid : IndustrialFluid;
            out item outletFluid : IndustrialFluid;
            in attribute speed : Units::RotationalSpeedValue;
            
            // Rotor turns within stator, forming sealed cavities
            // that progress from suction to discharge
            perform action FormCavities;
            perform action ProgressCavities;
            perform action DischargeFluid;
        }

        action FormCavities {
            // Helical rotor within double-helix stator creates sealed cavities
        }

        action ProgressCavities {
            // Cavities progress axially along pump as rotor turns
        }

        action DischargeFluid {
            // Fluid is gently and continuously pushed to discharge outlet
        }
    }

    part def ThreePhaseInductionMotor {
        port powerInput : ElectricalPowerPort;
        port driveOutput : MechanicalDrivePort;
        
        attribute ratedPower : Units::PowerValue;
        attribute ratedVoltage : Units::VoltageValue;
        attribute ratedSpeed : Units::RotationalSpeedValue;
        attribute poles : Integer;
        attribute efficiency : Real;
        attribute currentSpeed : Units::RotationalSpeedValue;
        attribute currentTorque : Units::TorqueValue;

        action def ConvertElectricalToMechanical {
            in item power : ElectricalPower;
            out attribute speed : Units::RotationalSpeedValue;
            out attribute torque : Units::TorqueValue;
            
            // Synchronous speed = 120 * frequency / poles
            perform action GenerateRotatingField;
            perform action InduceRotorCurrent;
            perform action ProduceTorque;
        }

        action GenerateRotatingField {}
        action InduceRotorCurrent {}
        action ProduceTorque {}
    }

    part def VariableFrequencyDrive {
        port powerInput : ElectricalPowerPort;
        port powerOutput : ElectricalPowerPort;
        port control : ControlPort;
        
        attribute inputFrequency : Units::FrequencyValue = 50;
        attribute outputFrequency : Units::FrequencyValue;
        attribute outputVoltage : Units::VoltageValue;
        attribute minFrequency : Units::FrequencyValue = 0;
        attribute maxFrequency : Units::FrequencyValue = 60;
        attribute rampRate : Real;

        action def RegulateFrequency {
            in attribute targetFlowRate : Units::FlowRateValueLpm;
            in attribute currentFlowRate : Units::FlowRateValueLpm;
            out attribute adjustedFrequency : Units::FrequencyValue;
            
            // Adjusts electrical frequency supplied to motor
            // for smooth adjustments to pumping speed
            perform action ComputeDesiredSpeed;
            perform action RampFrequency;
        }

        action ComputeDesiredSpeed {}
        action RampFrequency {}
    }

    part def Controller {
        port control : ControlPort;
        port vfdControl : ControlPort;
        port motorControl : ControlPort;
        
        in attribute suctionPressure : Units::PressureValue;
        in attribute suctionTemperature : Units::TemperatureValueCelsius;
        in attribute dischargePressure : Units::PressureValue;
        in attribute dischargeTemperature : Units::TemperatureValueCelsius;
        in attribute actualFlowRate : Units::FlowRateValueLpm;
        
        attribute targetFlowRate : Units::FlowRateValueLpm;
        attribute cavitationThreshold : Units::PressureValueBar = 0.2;
        attribute highPressureThreshold : Units::PressureValueBar = 10;
        attribute highTemperatureThreshold : Units::TemperatureValueCelsius = 80;
        
        attribute emergencyStopRequested : Boolean = false;

        action def MonitorSystem {
            // Continuously monitor all sensor readings
            perform action ReadSensors;
            perform action EvaluateSafetyConditions;
            perform action AdjustFlowRate;
        }

        action ReadSensors {}
        action EvaluateSafetyConditions {
            // Detect cavitation: low suction pressure
            // Detect over-pressure
            // Detect over-temperature
        }
        action AdjustFlowRate {
            // Adjust VFD output frequency based on commands
        }
    }

    // ---- State Machine ----

    state def SystemLifecycle {
        entry; then idle;

        state idle {
            // System powered but not pumping
            entry action InitializeSystem;
            accept ControlSignal
                when command == "start"
                then priming;
        }

        state priming {
            // Filling pump casing with fluid to avoid dry running
            entry action OpenSuctionValve;
            perform action PrimePumpCasing;
            accept ControlSignal
                when command == "primeComplete"
                then starting;
        }

        state starting {
            // Ramp up motor speed via VFD
            entry action StartVFD;
            perform action RampMotorSpeed;
            accept ControlSignal
                when command == "run"
                then running;
        }

        state running {
            // Normal operation with sub-states
            entry action EnterRunningMode;

            state normalOperation {
                // Steady-state pumping at commanded flow rate
                entry action MaintainFlowRate;
            }

            state adjustingFlow {
                // Adjusting flow rate based on commands
                entry action ModifyVFDOutput;
                accept ControlSignal
                    when command == "adjustComplete"
                    then normalOperation;
            }

            state protectiveState {
                // Protective mode due to cavitation or dangerous condition
                entry action ReduceSpeed;
                perform action MonitorRecovery;
                accept ControlSignal
                    when command == "conditionResolved"
                    then normalOperation;
            }

            transition from normalOperation to adjustingFlow
                accept ControlSignal
                when command == "adjustFlow";
            
            transition from normalOperation to protectiveState
                when suctionPressure < cavitationThreshold
                or dischargePressure > highPressureThreshold
                or dischargeTemperature > highTemperatureThreshold;
            
            transition from adjustingFlow to protectiveState
                when suctionPressure < cavitationThreshold;
        }

        state stopping {
            // Controlled shutdown
            entry action RampDownMotor;
            perform action CloseValves;
            accept ControlSignal
                when command == "stopComplete"
                then idle;
        }

        transition from running to stopping
            accept ControlSignal
            when command == "stop";

        // Emergency stop from any state
        transition from idle to emergencyStopped
            accept ControlSignal
            when command == "emergencyStop";
        
        transition from priming to emergencyStopped
            accept ControlSignal
            when command == "emergencyStop";
        
        transition from starting to emergencyStopped
            accept ControlSignal
            when command == "emergencyStop";
        
        transition from running to emergencyStopped
            accept ControlSignal
            when command == "emergencyStop";
        
        transition from stopping to emergencyStopped
            accept ControlSignal
            when command == "emergencyStop";

        state emergencyStopped {
            // Immediate halt of all operations
            entry action CutPower;
            entry action CloseAllValves;
            accept ControlSignal
                when command == "reset"
                then idle;
        }
    }

    action def InitializeSystem {}
    action def OpenSuctionValve {}
    action def PrimePumpCasing {}
    action def StartVFD {}
    action def RampMotorSpeed {}
    action def EnterRunningMode {}
    action def MaintainFlowRate {}
    action def ModifyVFDOutput {}
    action def ReduceSpeed {}
    action def MonitorRecovery {}
    action def RampDownMotor {}
    action def CloseValves {}
    action def CloseAllValves {}
    action def CutPower {}

    // ---- Top-level System Assembly ----

    part def FluidTransferSystem {
        port systemControl : ControlPort;
        
        part supplyReservoir : SupplyReservoir {
            attribute capacity = 1000;
            attribute fillLevel = 800;
        }

        part suctionPressureSensor : SuctionPressureSensor {
            attribute accuracy = 0.5;
        }

        part suctionTemperatureSensor : SuctionTemperatureSensor {
            attribute accuracy = 0.2;
        }

        part pump : ProgressingCavityPump {
            attribute nominalFlowRate = 150;
            attribute maxPressure = 12;
            redefines rotor.material = "Hardened Steel";
            redefines stator.material = "EPDM Rubber";
            redefines stator.elastomerType = "EPDM";
        }

        part dischargePressureSensor : DischargePressureSensor {
            attribute accuracy = 0.5;
        }

        part dischargeTemperatureSensor : DischargeTemperatureSensor {
            attribute accuracy = 0.2;
        }

        part flowMeter : FlowMeter {
            attribute accuracy = 1.0;
        }

        part dischargeVessel : DischargeVessel {
            attribute capacity = 2000;
            attribute fillLevel = 0;
        }

        part motor : ThreePhaseInductionMotor {
            attribute ratedPower = 5500;
            attribute ratedVoltage = 400;
            attribute ratedSpeed = 1450;
            attribute poles = 4;
            attribute efficiency = 0.92;
        }

        part vfd : VariableFrequencyDrive {
            attribute inputFrequency = 50;
            attribute maxFrequency = 60;
            attribute rampRate = 5.0;
        }

        part controller : Controller {
            attribute cavitationThreshold = 0.2;
            attribute highPressureThreshold = 10;
            attribute highTemperatureThreshold = 80;
        }

        // Fluid path connections
        connection supplyReservoir.fluidOut to suctionPressureSensor.fluidIn;
        connection suctionPressureSensor.fluidIn to suctionTemperatureSensor.fluidIn;
        connection suctionTemperatureSensor.fluidIn to pump.suctionPort;
        connection pump.dischargePort to dischargePressureSensor.fluidIn;
        connection dischargePressureSensor.fluidIn to dischargeTemperatureSensor.fluidIn;
        connection dischargeTemperatureSensor.fluidIn to flowMeter.fluidIn;
        connection flowMeter.fluidOut to dischargeVessel.fluidIn;

        // Mechanical drive connection
        connection motor.driveOutput to pump.driveInput;

        // Electrical power connections
        connection vfd.powerOutput to motor.powerInput;

        // Control connections
        connection controller.vfdControl to vfd.control;

        // Sensor feedback connections
        connection suctionPressureSensor.output to controller.control;
        connection suctionTemperatureSensor.output to controller.control;
        connection dischargePressureSensor.output to controller.control;
        connection dischargeTemperatureSensor.output to controller.control;
        connection flowMeter.output to controller.control;

        // System lifecycle behavior
        perform SystemLifecycle;
    }

    // ---- Requirements ----

    requirement def FluidTransferRequirement {
        subject system : FluidTransferSystem;
        doc /* The system shall precisely move fluid from a supply reservoir to a discharge vessel. */
    }

    requirement PreciseFlowControl :> FluidTransferRequirement {
        doc /* The system shall control flow rate within +/- 2% of the commanded setpoint. */
        attribute flowAccuracy : Real = 0.02;
    }

    requirement PressureControl :> FluidTransferRequirement {
        doc /* The system shall maintain discharge pressure below the maximum rated pressure. */
        attribute maxDischargePressure : Units::PressureValueBar = 12;
    }

    requirement ViscousFluidHandling :> FluidTransferRequirement {
        doc /* The system shall handle fluids with viscosity up to 10000 cP and fluids containing solids. */
        attribute maxViscosity : Units::ViscosityValue = 10;
    }

    requirement VFDSpeedRegulation :> FluidTransferRequirement {
        doc /* The VFD shall regulate motor speed by adjusting electrical frequency from 0 to 60 Hz. */
        attribute minFrequency : Units::FrequencyValue = 0;
        attribute maxFrequency : Units::FrequencyValue = 60;
    }

    requirement CavitationProtection :> FluidTransferRequirement {
        doc /* The system shall enter a protective state when suction pressure falls below the cavitation threshold. */
        attribute cavitationThreshold : Units::PressureValueBar = 0.2;
    }

    requirement EmergencyStopCapability :> FluidTransferRequirement {
        doc /* The system shall provide an emergency stop function that halts operations from any state. */
    }

    requirement ControlledLifecycle :> FluidTransferRequirement {
        doc /* The system shall follow a controlled lifecycle: idle, priming, starting, running, and stopping. */
    }

    requirement PumpSealing :> FluidTransferRequirement {
        doc /* The pump assembly shall be sealed at both suction and discharge ends. */
    }

    requirement ContinuousGentlePumping :> FluidTransferRequirement {
        doc /* The progressing cavity pump shall gently and continuously push fluid via progressing sealed cavities. */
    }

    requirement SensorInstrumentation :> FluidTransferRequirement {
        doc /* The system shall measure suction pressure, suction temperature, discharge pressure, discharge temperature, and actual flow rate. */
    }

    requirement SatisfySystemRequirements {
        subject system : FluidTransferSystem;
        satisfy PreciseFlowControl;
        satisfy PressureControl;
        satisfy ViscousFluidHandling;
        satisfy VFDSpeedRegulation;
        satisfy CavitationProtection;
        satisfy EmergencyStopCapability;
        satisfy ControlledLifecycle;
        satisfy PumpSealing;
        satisfy ContinuousGentlePumping;
        satisfy SensorInstrumentation;
    }

}
