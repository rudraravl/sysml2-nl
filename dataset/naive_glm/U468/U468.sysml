package ESP_Artificial_Lift_System {

import ScalarValues::*;

// ==================== VALUE TYPES WITH UNITS ====================

value type PressureValue > Real { unit 'Pa'; }
value type TemperatureValue > Real { unit 'degC'; }
value type FrequencyValue > Real { unit 'Hz'; }
value type FlowRateValue > Real { unit 'm3/s'; }
value type VibrationLevelValue > Real { unit 'g'; }
value type PowerValue > Real { unit 'W'; }
value type VoltageValue > Real { unit 'V'; }
value type CurrentValue > Real { unit 'A'; }
value type RotationalSpeedValue > Real { unit 'rpm'; }
value type LengthValue > Real { unit 'm'; }
value type DepthValue > Real { unit 'm'; }
value type DiameterValue > Real { unit 'm'; }
value type EfficiencyValue > Real { unit '1'; }
value type VolumeFractionValue > Real { unit '1'; }
value type MassFractionValue > Real { unit '1'; }

// ==================== ITEM DEFINITIONS ====================

item def WellFluid {
    attribute pressure : PressureValue;
    attribute temperature : TemperatureValue;
    attribute waterFraction : VolumeFractionValue;
    attribute gasFraction : VolumeFractionValue;
}

item def Oil {
    attribute pressure : PressureValue;
    attribute temperature : TemperatureValue;
    attribute density : Real;
}

item def Gas {
    attribute pressure : PressureValue;
    attribute temperature : TemperatureValue;
    attribute density : Real;
}

item def Water {
    attribute pressure : PressureValue;
    attribute temperature : TemperatureValue;
    attribute salinity : MassFractionValue;
}

item def ElectricalPower {
    attribute voltage : VoltageValue;
    attribute current : CurrentValue;
    attribute frequency : FrequencyValue;
    attribute power : PowerValue;
}

item def MechanicalTorque {
    attribute rotationalSpeed : RotationalSpeedValue;
    attribute torqueValue : Real;
}

item def ControlCommand {
    attribute commandType : String;
    attribute targetFrequency : FrequencyValue;
    attribute priority : Integer;
}

item def SensorData {
    attribute sensorType : String;
    attribute value : Real;
    attribute unit : String;
    attribute timestamp : Real;
}

item def AlarmData {
    attribute alarmId : String;
    attribute severity : Integer;
    attribute description : String;
    attribute timestamp : Real;
}

// ==================== PORT DEFINITIONS ====================

port def FluidInletPort {
    in item : WellFluid;
}

port def FluidOutletPort {
    out item : WellFluid;
}

port def OilOutletPort {
    out item : Oil;
}

port def GasOutletPort {
    out item : Gas;
}

port def WaterOutletPort {
    out item : Water;
}

port def ElectricalInputPort {
    in item : ElectricalPower;
}

port def ElectricalOutputPort {
    out item : ElectricalPower;
}

port def DataOutPort {
    out item : SensorData;
}

port def DataInPort {
    in item : SensorData;
}

port def CommandOutPort {
    out item : ControlCommand;
}

port def CommandInPort {
    in item : ControlCommand;
}

port def AlarmOutPort {
    out item : AlarmData;
}

port def ShaftOutputPort {
    out item : MechanicalTorque;
}

port def ShaftInputPort {
    in item : MechanicalTorque;
}

// ==================== CONNECTION DEFINITIONS ====================

connection def FluidConnection {
    end source : FluidOutletPort;
    end target : FluidInletPort;
}

connection def ElectricalConnection {
    end source : ElectricalOutputPort;
    end target : ElectricalInputPort;
}

connection def DataConnection {
    end source : DataOutPort;
    end target : DataInPort;
}

connection def CommandConnection {
    end source : CommandOutPort;
    end target : CommandInPort;
}

connection def ShaftConnection {
    end source : ShaftOutputPort;
    end target : ShaftInputPort;
}

// ==================== DOWNHOLE SENSORS ====================

part def BottomHolePressureSensor {
    port fluidIn : FluidInletPort;
    port dataOut : DataOutPort;

    attribute measuredPressure : PressureValue;
    attribute measurementRange : PressureValue = 50000000;
    attribute samplingRate : FrequencyValue = 1;

    action measurePressure {
        out pressure : PressureValue;
    }

    action transmitPressureData {
        in pressure : PressureValue;
        out data : SensorData;
    }
}

part def MotorTemperatureSensor {
    port dataOut : DataOutPort;

    attribute measuredTemperature : TemperatureValue;
    attribute maxOperatingTemp : TemperatureValue = 150;
    attribute samplingRate : FrequencyValue = 1;

    action measureTemperature {
        out temperature : TemperatureValue;
    }

    action transmitTemperatureData {
        in temperature : TemperatureValue;
        out data : SensorData;
    }
}

part def VibrationSensor {
    port dataOut : DataOutPort;

    attribute measuredVibration : VibrationLevelValue;
    attribute maxVibrationLevel : VibrationLevelValue = 10.0;
    attribute samplingRate : FrequencyValue = 10;

    action measureVibration {
        out vibration : VibrationLevelValue;
    }

    action transmitVibrationData {
        in vibration : VibrationLevelValue;
        out data : SensorData;
    }
}

part def SurfaceFlowMeter {
    port fluidIn : FluidInletPort;
    port fluidOut : FluidOutletPort;
    port dataOut : DataOutPort;

    attribute measuredFlowRate : FlowRateValue;
    attribute targetFlowRate : FlowRateValue = 0.02;
    attribute fullScaleRange : FlowRateValue = 0.1;

    action measureFlowRate {
        in fluid : WellFluid;
        out flowRate : FlowRateValue;
    }

    action transmitFlowData {
        in flowRate : FlowRateValue;
        out data : SensorData;
    }
}

// ==================== DOWNHOLE ACTUATION COMPONENTS ====================

part def ElectricMotor {
    port powerIn : ElectricalInputPort;
    port shaftOut : ShaftOutputPort;

    attribute ratedPower : PowerValue = 100000;
    attribute ratedVoltage : VoltageValue = 480;
    attribute ratedFrequency : FrequencyValue = 60;
    attribute operatingTemperature : TemperatureValue;
    attribute rotationalSpeed : RotationalSpeedValue;
    attribute poleCount : Integer = 2;

    action generateTorque {
        in electricPower : ElectricalPower;
        out torque : MechanicalTorque;
    }
}

part def CentrifugalPump {
    port fluidIn : FluidInletPort;
    port fluidOut : FluidOutletPort;
    port shaftIn : ShaftInputPort;

    attribute numberOfStages : Integer = 20;
    attribute ratedFlowRate : FlowRateValue = 0.02;
    attribute dischargePressure : PressureValue;
    attribute pumpEfficiency : EfficiencyValue = 0.6;
    attribute stageDiameter : DiameterValue = 0.1;

    action pumpFluid {
        in torque : MechanicalTorque;
        in intakeFluid : WellFluid;
        out dischargedFluid : WellFluid;
    }
}

part def PowerCable {
    port powerIn : ElectricalInputPort;
    port powerOut : ElectricalOutputPort;

    attribute cableLength : LengthValue = 1500;
    attribute conductorResistance : Real;
    attribute ratedVoltage : VoltageValue = 480;

    action transmitPower {
        in inputPower : ElectricalPower;
        out outputPower : ElectricalPower;
    }
}

// ==================== DOWNHOLE ASSEMBLY ====================

part def DownholeAssembly {
    port fluidIn : FluidInletPort;
    port fluidOut : FluidOutletPort;
    port powerIn : ElectricalInputPort;
    port bhpDataOut : DataOutPort;
    port tempDataOut : DataOutPort;
    port vibDataOut : DataOutPort;

    attribute installationDepth : DepthValue = 1500;
    attribute ambientTemperature : TemperatureValue = 80;

    part motor : ElectricMotor;
    part pump : CentrifugalPump;
    part bhpSensor : BottomHolePressureSensor;
    part tempSensor : MotorTemperatureSensor;
    part vibSensor : VibrationSensor;

    connection powerFeedToMotor connect powerIn to motor.powerIn;
    connection motorToPumpShaft connect motor.shaftOut to pump.shaftIn;
    connection fluidToPump connect fluidIn to pump.fluidIn;
    connection fluidFromPump connect pump.fluidOut to fluidOut;
    connection fluidToBHPSensor connect fluidIn to bhpSensor.fluidIn;
    connection bhpSensorDataOut connect bhpSensor.dataOut to bhpDataOut;
    connection tempSensorDataOut connect tempSensor.dataOut to tempDataOut;
    connection vibSensorDataOut connect vibSensor.dataOut to vibDataOut;
}

// ==================== SURFACE POWER AND CONTROL ====================

part def GridPowerSource {
    port powerOut : ElectricalOutputPort;

    attribute gridVoltage : VoltageValue = 480;
    attribute gridFrequency : FrequencyValue = 60;
    attribute gridPower : PowerValue = 200000;

    action supplyPower {
        out power : ElectricalPower;
    }
}

part def VariableFrequencyDrive {
    port powerIn : ElectricalInputPort;
    port commandIn : CommandInPort;
    port powerOut : ElectricalOutputPort;

    attribute inputFrequency : FrequencyValue = 60;
    attribute outputFrequency : FrequencyValue;
    attribute inputVoltage : VoltageValue = 480;
    attribute maxFrequency : FrequencyValue = 70;
    attribute minFrequency : FrequencyValue = 30;
    attribute ratedPower : PowerValue = 150000;
    attribute rampRate : FrequencyValue = 5;
    attribute currentOutputCurrent : CurrentValue;

    action adjustFrequency {
        in command : ControlCommand;
        in inputPower : ElectricalPower;
        out outputPower : ElectricalPower;
    }

    action rampUp {
        in targetFreq : FrequencyValue;
    }

    action rampDown {
        in targetFreq : FrequencyValue;
    }

    action emergencyStop;
}

// ==================== SURFACE CONTROLLER ====================

part def SurfaceController {
    port bhpDataIn : DataInPort;
    port tempDataIn : DataInPort;
    port vibDataIn : DataInPort;
    port flowDataIn : DataInPort;
    port commandOut : CommandOutPort;
    port alarmOut : AlarmOutPort;

    attribute targetFlowRate : FlowRateValue = 0.02;
    attribute minBHP : PressureValue = 5000000;
    attribute maxMotorTemp : TemperatureValue = 150;
    attribute maxVibration : VibrationLevelValue = 10.0;

    attribute currentBHP : PressureValue;
    attribute currentMotorTemp : TemperatureValue;
    attribute currentVibration : VibrationLevelValue;
    attribute currentFlowRate : FlowRateValue;
    attribute currentMotorFrequency : FrequencyValue;

    attribute startCommandReceived : Boolean = false;
    attribute motorAtTargetSpeed : Boolean = false;
    attribute startTimeout : Boolean = false;
    attribute unsafeDetected : Boolean = false;
    attribute resetReceived : Boolean = false;

    action evaluateConditions {
        in bhpData : SensorData;
        in tempData : SensorData;
        in vibData : SensorData;
        in flowData : SensorData;
    }

    action computeAdjustment {
        in bhp : PressureValue;
        in flowRate : FlowRateValue;
        in motorTemp : TemperatureValue;
        in vibration : VibrationLevelValue;
        out command : ControlCommand;
    }

    action generateAlarm {
        out alarm : AlarmData;
    }

    action performReset;

    state machine operationalStates {
        state idle;
        state starting;
        state running;
        state fault;

        transition from idle to starting when startCommandReceived;
        transition from starting to running when motorAtTargetSpeed;
        transition from starting to fault when startTimeout;
        transition from running to fault when unsafeDetected;
        transition from fault to idle when resetReceived;
    }
}

// ==================== PRODUCTION TUBING ====================

part def ProductionTubing {
    port fluidIn : FluidInletPort;
    port fluidOut : FluidOutletPort;

    attribute length : LengthValue = 1500;
    attribute innerDiameter : DiameterValue = 0.1;
    attribute wallThickness : DiameterValue = 0.006;

    action transportFluid {
        in fluid : WellFluid;
        out fluid : WellFluid;
    }
}

// ==================== SEPARATOR VESSEL ====================

part def SeparatorVessel {
    port fluidIn : FluidInletPort;
    port oilOut : OilOutletPort;
    port gasOut : GasOutletPort;
    port waterOut : WaterOutletPort;

    attribute operatingPressure : PressureValue = 1000000;
    attribute operatingTemperature : TemperatureValue = 50;
    attribute capacity : FlowRateValue = 0.05;

    action separateFluid {
        in fluid : WellFluid;
        out oil : Oil;
        out gas : Gas;
        out water : Water;
    }
}

// ==================== ESP SYSTEM ====================

part def ESPSystem {
    part gridPower : GridPowerSource;
    part vfd : VariableFrequencyDrive;
    part powerCable : PowerCable;
    part downholeAssembly : DownholeAssembly;
    part productionTubing : ProductionTubing;
    part surfaceFlowMeter : SurfaceFlowMeter;
    part surfaceController : SurfaceController;
    part separator : SeparatorVessel;

    // Electrical power chain
    connection gridToVFD connect gridPower.powerOut to vfd.powerIn;
    connection vfdToCable connect vfd.powerOut to powerCable.powerIn;
    connection cableToDownhole connect powerCable.powerOut to downholeAssembly.powerIn;

    // Fluid flow chain
    connection downholeToTubing connect downholeAssembly.fluidOut to productionTubing.fluidIn;
    connection tubingToFlowMeter connect productionTubing.fluidOut to surfaceFlowMeter.fluidIn;
    connection flowMeterToSeparator connect surfaceFlowMeter.fluidOut to separator.fluidIn;

    // Sensor data to controller
    connection bhpDataToController connect downholeAssembly.bhpDataOut to surfaceController.bhpDataIn;
    connection tempDataToController connect downholeAssembly.tempDataOut to surfaceController.tempDataIn;
    connection vibDataToController connect downholeAssembly.vibDataOut to surfaceController.vibDataIn;
    connection flowDataToController connect surfaceFlowMeter.dataOut to surfaceController.flowDataIn;

    // Control command to VFD
    connection controllerToVFD connect surfaceController.commandOut to vfd.commandIn;
}

// ==================== SYSTEM INSTANTIATION ====================

part espSystem : ESPSystem;

// ==================== REQUIREMENTS ====================

requirement def AutomatedProductionControl {
    doc {
        The ESP system shall maintain production at or near the target flow rate by automatically adjusting the VFD output frequency based on real-time sensor feedback.
    }
    subject system : ESPSystem;
    attribute targetFlowRate : FlowRateValue = 0.02;
    attribute tolerance : Real = 0.05;
    constraint {
        system.surfaceController.currentFlowRate >= targetFlowRate * (1 - tolerance)
        and system.surfaceController.currentFlowRate <= targetFlowRate * (1 + tolerance)
    }
}

requirement def MotorOverheatProtection {
    doc {
        The system shall automatically trigger a fault-state shutdown when the motor temperature exceeds the maximum safe operating temperature.
    }
    subject system : ESPSystem;
    attribute maxTemp : TemperatureValue = 150;
    constraint {
        system.surfaceController.currentMotorTemp <= maxTemp
    }
}

requirement def ReservoirPressureProtection {
    doc {
        The system shall prevent the bottom-hole pressure from dropping below the minimum safe reservoir pressure to avoid reservoir damage.
    }
    subject system : ESPSystem;
    attribute minPressure : PressureValue = 5000000;
    constraint {
        system.surfaceController.currentBHP >= minPressure
    }
}

requirement def VibrationSafetyProtection {
    doc {
        The system shall trigger a fault-state shutdown if vibration levels exceed the maximum safe threshold, indicating potential mechanical failure.
    }
    subject system : ESPSystem;
    attribute maxVib : VibrationLevelValue = 10.0;
    constraint {
        system.surfaceController.currentVibration <= maxVib
    }
}

requirement def FaultStateResetRequirement {
    doc {
        After a fault condition triggers automatic shutdown, the system shall require a manual reset before resuming operation from the idle state.
    }
    subject system : ESPSystem;
}

requirement def VFDControlAuthority {
    doc {
        The VFD shall modulate the electrical frequency supplied to the downhole motor between minimum and maximum frequency limits as commanded by the surface controller.
    }
    subject system : ESPSystem;
    attribute minFreq : FrequencyValue = 30;
    attribute maxFreq : FrequencyValue = 70;
    constraint {
        system.vfd.outputFrequency >= minFreq
        and system.vfd.outputFrequency <= maxFreq
    }
}

requirement def ContinuousMonitoringRequirement {
    doc {
        The surface controller shall continuously monitor bottom-hole pressure, motor temperature, vibration levels, and surface flow rate at all times during operation.
    }
    subject system : ESPSystem;
}

requirement def SeparatorOutputRequirement {
    doc {
        The separator vessel shall separate the produced well fluid into oil, gas, and water streams for downstream processing.
    }
    subject system : ESPSystem;
}

// ==================== REQUIREMENT USAGES ====================

requirement automatedProductionControl : AutomatedProductionControl;
requirement motorOverheatProtection : MotorOverheatProtection;
requirement reservoirPressureProtection : ReservoirPressureProtection;
requirement vibrationSafetyProtection : VibrationSafetyProtection;
requirement faultStateReset : FaultStateResetRequirement;
requirement vfdControlAuthority : VFDControlAuthority;
requirement continuousMonitoring : ContinuousMonitoringRequirement;
requirement separatorOutput : SeparatorOutputRequirement;

// ==================== SATISFACTION ====================

satisfy automatedProductionControl by espSystem;
satisfy motorOverheatProtection by espSystem;
satisfy reservoirPressureProtection by espSystem;
satisfy vibrationSafetyProtection by espSystem;
satisfy faultStateReset by espSystem;
satisfy vfdControlAuthority by espSystem;
satisfy continuousMonitoring by espSystem;
satisfy separatorOutput by espSystem;

}
