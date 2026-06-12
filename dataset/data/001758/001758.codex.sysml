package CarIndustrySystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def VehicleSpeed :> speed {
        unit = "km/h";
    }

    attribute def Distance :> length {
        unit = "km";
    }

    attribute def FuelVolume :> volume {
        unit = "L";
    }

    attribute def ElectricCharge :> scalar {
        unit = "kWh";
    }

    attribute def RotationalSpeed :> scalar {
        unit = "rpm";
    }

    attribute def Torque :> scalar {
        unit = "N*m";
    }

    attribute def Force :> scalar {
        unit = "N";
    }

    attribute def Pressure :> scalar {
        unit = "kPa";
    }

    attribute def Temperature :> scalar {
        unit = "degC";
    }

    attribute def Percentage :> scalar {
        unit = "%";
    }

    item def Fuel {
        attribute volume : FuelVolume;
        attribute octaneRating : Real;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute energyAvailable : ElectricCharge;
    }

    item def MechanicalPower {
        attribute torque : Torque;
        attribute shaftSpeed : RotationalSpeed;
    }

    item def BrakeHydraulicPressure {
        attribute pressure : Pressure;
    }

    item def DriverCommand {
        attribute acceleratorPedal : Percentage;
        attribute brakePedal : Percentage;
        attribute steeringAngle : Real;
        attribute gearSelection : GearPosition;
        attribute ignitionRequest : Boolean;
    }

    item def VehicleMotion {
        attribute speed : VehicleSpeed;
        attribute heading : Real;
        attribute acceleration : Real;
        attribute distanceTraveled : Distance;
    }

    item def DiagnosticMessage {
        attribute severity : DiagnosticSeverity;
        attribute code : String;
        attribute message : String;
    }

    enum def GearPosition {
        enum park;
        enum reverse;
        enum neutral;
        enum drive;
        enum low;
    }

    enum def DiagnosticSeverity {
        enum info;
        enum warning;
        enum fault;
        enum critical;
    }

    port def FuelPort {
        out item fuel : Fuel;
    }

    port def ElectricalPort {
        inout item power : ElectricalPower;
    }

    port def MechanicalPowerPort {
        inout item power : MechanicalPower;
    }

    port def BrakePressurePort {
        inout item pressure : BrakeHydraulicPressure;
    }

    port def DriverCommandPort {
        in item command : DriverCommand;
    }

    port def MotionPort {
        out item motion : VehicleMotion;
    }

    port def DiagnosticPort {
        out item diagnostic : DiagnosticMessage;
    }

    port def ThermalPort {
        inout attribute temperature : Temperature;
    }

    action def ConvertFuelToMechanicalPower {
        in item fuel : Fuel;
        in attribute throttle : Percentage;
        out item mechanicalPower : MechanicalPower;
    }

    action def ConvertElectricalToMechanicalPower {
        in item electricalPower : ElectricalPower;
        in attribute torqueDemand : Torque;
        out item mechanicalPower : MechanicalPower;
    }

    action def TransmitTorqueToWheels {
        in item enginePower : MechanicalPower;
        in item motorPower : MechanicalPower;
        in attribute selectedGear : GearPosition;
        out item wheelPower : MechanicalPower;
    }

    action def GenerateBrakingForce {
        in item pressure : BrakeHydraulicPressure;
        in attribute wheelSpeed : RotationalSpeed;
        out attribute brakingForce : Force;
    }

    action def MaintainCabinEnvironment {
        in attribute requestedTemperature : Temperature;
        inout attribute cabinTemperature : Temperature;
    }

    action def PropelVehicle {
        in item wheelPower : MechanicalPower;
        in attribute brakingForce : Force;
        out item motion : VehicleMotion;
    }

    state def VehicleOperatingState {
        entry action initializeDiagnostics;
        state Off;
        state Accessory;
        state Ready;
        state Propelling;
        state Braking;
        state Parked;
        state Faulted;

        transition first Off;
        transition Off_to_Accessory
            first Off
            then Accessory
            if ignitionRequest == true;

        transition Accessory_to_Ready
            first Accessory
            then Ready
            if powertrainAvailable == true;

        transition Ready_to_Propelling
            first Ready
            then Propelling
            if acceleratorPedal > 0 and gearSelection == GearPosition::drive;

        transition Propelling_to_Braking
            first Propelling
            then Braking
            if brakePedal > 0;

        transition Braking_to_Ready
            first Braking
            then Ready
            if brakePedal == 0 and acceleratorPedal == 0;

        transition Ready_to_Parked
            first Ready
            then Parked
            if gearSelection == GearPosition::park;

        transition Any_to_Faulted
            first Off
            then Faulted
            if criticalFaultDetected == true;
    }

    part def FuelTank {
        attribute capacity : FuelVolume = 55 [L];
        attribute currentFuel : FuelVolume;
        attribute fuelLevel : Percentage;
        port fuelOut : FuelPort;
        port diagnosticOut : DiagnosticPort;
    }

    part def BatteryPack {
        attribute capacity : ElectricCharge = 2.0 [kWh];
        attribute stateOfCharge : Percentage;
        attribute nominalVoltage : Real = 350;
        port electrical : ElectricalPort;
        port thermal : ThermalPort;
        port diagnosticOut : DiagnosticPort;
    }

    part def InternalCombustionEngine {
        attribute displacement : Real = 2.0;
        attribute peakTorque : Torque = 320 [N*m];
        attribute idleSpeed : RotationalSpeed = 750 [rpm];
        attribute coolantTemperature : Temperature;
        port fuelIn : FuelPort;
        port crankshaftOut : MechanicalPowerPort;
        port electrical : ElectricalPort;
        port thermal : ThermalPort;
        port diagnosticOut : DiagnosticPort;

        perform action combustion : ConvertFuelToMechanicalPower;
    }

    part def ElectricMotor {
        attribute peakTorque : Torque = 180 [N*m];
        attribute maximumSpeed : RotationalSpeed = 12000 [rpm];
        attribute windingTemperature : Temperature;
        port electrical : ElectricalPort;
        port shaftOut : MechanicalPowerPort;
        port thermal : ThermalPort;
        port diagnosticOut : DiagnosticPort;

        perform action electromechanicalConversion : ConvertElectricalToMechanicalPower;
    }

    part def Transmission {
        attribute forwardGearCount : Integer = 8;
        attribute currentGear : GearPosition;
        attribute efficiency : Percentage = 94 [%];
        port engineShaftIn : MechanicalPowerPort;
        port motorShaftIn : MechanicalPowerPort;
        port driveshaftOut : MechanicalPowerPort;
        port diagnosticOut : DiagnosticPort;

        perform action torqueTransfer : TransmitTorqueToWheels;
    }

    part def WheelAssembly {
        attribute wheelRadius : Real = 0.34;
        attribute tirePressure : Pressure = 240 [kPa];
        attribute wheelSpeed : RotationalSpeed;
        port drivePowerIn : MechanicalPowerPort;
        port brakePressureIn : BrakePressurePort;
        port motionOut : MotionPort;
        port diagnosticOut : DiagnosticPort;
    }

    part def BrakeSystem {
        attribute maximumBrakePressure : Pressure = 12000 [kPa];
        attribute brakeFluidTemperature : Temperature;
        port commandIn : DriverCommandPort;
        port pressureOut : BrakePressurePort;
        port electrical : ElectricalPort;
        port diagnosticOut : DiagnosticPort;

        perform action braking : GenerateBrakingForce;
    }

    part def SteeringSystem {
        attribute maximumSteeringAngle : Real = 38;
        attribute currentSteeringAngle : Real;
        port commandIn : DriverCommandPort;
        port electrical : ElectricalPort;
        port diagnosticOut : DiagnosticPort;
    }

    part def ThermalManagementSystem {
        attribute coolantTemperature : Temperature;
        attribute targetBatteryTemperature : Temperature = 30 [degC];
        port engineThermal : ThermalPort;
        port batteryThermal : ThermalPort;
        port motorThermal : ThermalPort;
        port electrical : ElectricalPort;
        port diagnosticOut : DiagnosticPort;
    }

    part def CabinSystem {
        attribute cabinTemperature : Temperature;
        attribute requestedCabinTemperature : Temperature = 22 [degC];
        port electrical : ElectricalPort;
        port diagnosticOut : DiagnosticPort;

        perform action climateControl : MaintainCabinEnvironment;
    }

    part def VehicleControlUnit {
        attribute acceleratorPedal : Percentage;
        attribute brakePedal : Percentage;
        attribute selectedGear : GearPosition;
        attribute ignitionRequest : Boolean;
        attribute powertrainAvailable : Boolean;
        attribute criticalFaultDetected : Boolean;
        port driverCommandIn : DriverCommandPort;
        port powerDistribution : ElectricalPort;
        port diagnosticOut : DiagnosticPort;

        exhibit state operatingState : VehicleOperatingState;
    }

    part def DriverInterface {
        attribute displayedSpeed : VehicleSpeed;
        attribute displayedFuelLevel : Percentage;
        attribute displayedStateOfCharge : Percentage;
        port commandOut : DriverCommandPort;
        port diagnosticIn : DiagnosticPort;
    }

    part def RoadVehicle {
        attribute curbMass : Real = 1650;
        attribute maximumSpeed : VehicleSpeed = 210 [km/h];
        attribute targetRange : Distance = 700 [km];
        attribute currentSpeed : VehicleSpeed;
        attribute totalDistanceTraveled : Distance;

        port driverCommand : DriverCommandPort;
        port vehicleMotion : MotionPort;
        port diagnostics : DiagnosticPort;

        part driverInterface : DriverInterface;
        part controller : VehicleControlUnit;
        part fuelTank : FuelTank;
        part batteryPack : BatteryPack;
        part engine : InternalCombustionEngine;
        part tractionMotor : ElectricMotor;
        part transmission : Transmission;
        part frontLeftWheel : WheelAssembly;
        part frontRightWheel : WheelAssembly;
        part rearLeftWheel : WheelAssembly;
        part rearRightWheel : WheelAssembly;
        part brakes : BrakeSystem;
        part steering : SteeringSystem;
        part thermalManagement : ThermalManagementSystem;
        part cabin : CabinSystem;

        connect driverInterface.commandOut to controller.driverCommandIn;
        connect controller.driverCommandIn to driverCommand;
        connect controller.powerDistribution to batteryPack.electrical;
        connect batteryPack.electrical to tractionMotor.electrical;
        connect batteryPack.electrical to brakes.electrical;
        connect batteryPack.electrical to steering.electrical;
        connect batteryPack.electrical to cabin.electrical;
        connect batteryPack.electrical to thermalManagement.electrical;

        connect fuelTank.fuelOut to engine.fuelIn;
        connect engine.crankshaftOut to transmission.engineShaftIn;
        connect tractionMotor.shaftOut to transmission.motorShaftIn;

        connect transmission.driveshaftOut to frontLeftWheel.drivePowerIn;
        connect transmission.driveshaftOut to frontRightWheel.drivePowerIn;
        connect transmission.driveshaftOut to rearLeftWheel.drivePowerIn;
        connect transmission.driveshaftOut to rearRightWheel.drivePowerIn;

        connect brakes.pressureOut to frontLeftWheel.brakePressureIn;
        connect brakes.pressureOut to frontRightWheel.brakePressureIn;
        connect brakes.pressureOut to rearLeftWheel.brakePressureIn;
        connect brakes.pressureOut to rearRightWheel.brakePressureIn;

        connect controller.driverCommandIn to brakes.commandIn;
        connect controller.driverCommandIn to steering.commandIn;

        connect engine.thermal to thermalManagement.engineThermal;
        connect batteryPack.thermal to thermalManagement.batteryThermal;
        connect tractionMotor.thermal to thermalManagement.motorThermal;

        connect frontLeftWheel.motionOut to vehicleMotion;
        connect frontRightWheel.motionOut to vehicleMotion;
        connect rearLeftWheel.motionOut to vehicleMotion;
        connect rearRightWheel.motionOut to vehicleMotion;

        connect controller.diagnosticOut to diagnostics;
        connect fuelTank.diagnosticOut to diagnostics;
        connect batteryPack.diagnosticOut to diagnostics;
        connect engine.diagnosticOut to diagnostics;
        connect tractionMotor.diagnosticOut to diagnostics;
        connect transmission.diagnosticOut to diagnostics;
        connect brakes.diagnosticOut to diagnostics;
        connect steering.diagnosticOut to diagnostics;
        connect thermalManagement.diagnosticOut to diagnostics;
        connect cabin.diagnosticOut to diagnostics;

        perform action vehiclePropulsion : PropelVehicle;
    }

    requirement def PrimaryFunctionRequirement {
        subject vehicle : RoadVehicle;
        doc /* The road vehicle shall transport occupants and cargo by converting stored chemical and electrical energy into controlled motion while providing steering, braking, thermal regulation, diagnostics, and driver interaction. */
    }

    requirement def RangeRequirement {
        subject vehicle : RoadVehicle;
        attribute minimumRange : Distance = 650 [km];
        require constraint { vehicle.targetRange >= minimumRange }
    }

    requirement def SpeedRequirement {
        subject vehicle : RoadVehicle;
        attribute requiredMaximumSpeed : VehicleSpeed = 180 [km/h];
        require constraint { vehicle.maximumSpeed >= requiredMaximumSpeed }
    }

    requirement def BrakingRequirement {
        subject vehicle : RoadVehicle;
        attribute maximumStoppingDistanceFrom100Kph : Distance = 0.04 [km];
        doc /* The brake system shall stop the vehicle from 100 km/h within 40 meters on dry level pavement. */
    }

    requirement def EnergyManagementRequirement {
        subject vehicle : RoadVehicle;
        doc /* The controller shall coordinate fuel engine output, electric motor assist, battery charge, and accessory loads to meet driver torque demand while protecting thermal and diagnostic limits. */
    }

    requirement def DriverControlRequirement {
        subject vehicle : RoadVehicle;
        doc /* The driver interface shall accept accelerator, brake, steering, gear, and ignition commands and provide vehicle status feedback including speed, fuel level, charge level, and faults. */
    }

    requirement def SafetyFaultRequirement {
        subject vehicle : RoadVehicle;
        doc /* On detection of a critical propulsion, braking, steering, or thermal fault, the vehicle shall enter a faulted operating state and issue a critical diagnostic message. */
    }

    part carIndustryProduct : RoadVehicle {
        attribute currentSpeed = 0 [km/h];
        attribute totalDistanceTraveled = 0 [km];
        attribute targetRange = 700 [km];
    }

    satisfy PrimaryFunctionRequirement by carIndustryProduct;
    satisfy RangeRequirement by carIndustryProduct;
    satisfy SpeedRequirement by carIndustryProduct;
    satisfy BrakingRequirement by carIndustryProduct;
    satisfy EnergyManagementRequirement by carIndustryProduct;
    satisfy DriverControlRequirement by carIndustryProduct;
    satisfy SafetyFaultRequirement by carIndustryProduct;
}