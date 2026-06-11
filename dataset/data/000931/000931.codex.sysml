package PumpingSubsystem_RotaryVanePump {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = SI::cubicMetrePerSecond;
    }

    attribute def AngularSpeed :> ISQ::angularVelocity {
        unit = SI::radianPerSecond;
    }

    attribute def Torque :> ISQ::torque {
        unit = SI::newtonMetre;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Volume :> ISQ::volume {
        unit = SI::cubicMetre;
    }

    attribute def DynamicViscosity :> ISQ::dynamicViscosity {
        unit = SI::pascalSecond;
    }

    enum def PumpOperatingMode {
        enum off;
        enum priming;
        enum running;
        enum bypassing;
        enum faulted;
        enum stopped;
    }

    enum def FaultCode {
        enum none;
        enum dryRun;
        enum overPressure;
        enum overTemperature;
        enum motorOverload;
        enum lowInletPressure;
        enum sealLeakage;
    }

    item def ProcessFluid {
        attribute density : ISQ::density;
        attribute viscosity : DynamicViscosity;
        attribute temperature : Temperature;
        attribute vaporPressure : Pressure;
        attribute cleanlinessClass : String;
    }

    item def ElectricalPower {
        attribute voltage : ISQ::electricPotential;
        attribute current : ISQ::electricCurrent;
        attribute frequency : ISQ::frequency;
        attribute power : Power;
    }

    item def ShaftPower {
        attribute speed : AngularSpeed;
        attribute torque : Torque;
        attribute power : Power;
    }

    item def ControlCommand {
        attribute enable : Boolean;
        attribute commandedSpeed : AngularSpeed;
        attribute resetFault : Boolean;
        attribute requestedMode : PumpOperatingMode;
    }

    item def PumpStatus {
        attribute actualMode : PumpOperatingMode;
        attribute actualSpeed : AngularSpeed;
        attribute dischargePressure : Pressure;
        attribute inletPressure : Pressure;
        attribute actualFlow : FlowRate;
        attribute fault : FaultCode;
        attribute ready : Boolean;
    }

    port def FluidInletPort {
        in item fluidIn : ProcessFluid;
        attribute staticPressure : Pressure;
        attribute temperature : Temperature;
    }

    port def FluidOutletPort {
        out item fluidOut : ProcessFluid;
        attribute staticPressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
    }

    port def ElectricalInputPort {
        in item powerIn : ElectricalPower;
    }

    port def MechanicalDrivePort {
        in item shaftPowerIn : ShaftPower;
        attribute rotationSpeed : AngularSpeed;
        attribute transmittedTorque : Torque;
    }

    port def CommandPort {
        in item commandIn : ControlCommand;
    }

    port def StatusPort {
        out item statusOut : PumpStatus;
    }

    port def LeakageDrainPort {
        out item leakageFluid : ProcessFluid;
        attribute leakageFlow : FlowRate;
    }

    port def ThermalPort {
        out attribute rejectedHeat : Power;
        out attribute casingTemperature : Temperature;
    }

    part def RotaryVanePumpingSubsystem {
        attribute ratedFlow : FlowRate = 0.003;
        attribute ratedDischargePressure : Pressure = 900000;
        attribute maximumDischargePressure : Pressure = 1200000;
        attribute minimumInletPressure : Pressure = 50000;
        attribute nominalSpeed : AngularSpeed = 183.26;
        attribute maximumSpeed : AngularSpeed = 209.44;
        attribute minimumPrimingSpeed : AngularSpeed = 52.36;
        attribute maximumFluidTemperature : Temperature = 363.15;
        attribute internalReliefSetPressure : Pressure = 1100000;
        attribute volumetricEfficiency : Real = 0.88;
        attribute mechanicalEfficiency : Real = 0.82;
        attribute displacementPerRevolution : Volume = 0.00000165;
        attribute operatingMode : PumpOperatingMode = PumpOperatingMode::off;
        attribute activeFault : FaultCode = FaultCode::none;

        port suction : FluidInletPort;
        port discharge : FluidOutletPort;
        port electricalSupply : ElectricalInputPort;
        port command : CommandPort;
        port status : StatusPort;
        port drain : LeakageDrainPort;
        port heatRejection : ThermalPort;

        part inletStrainer : InletStrainer;
        part isolationValve : ManualIsolationValve;
        part pump : RotaryVanePump;
        part driveMotor : ElectricMotor;
        part coupling : FlexibleCoupling;
        part reliefValve : InternalBypassReliefValve;
        part checkValve : DischargeCheckValve;
        part pressureSensorInlet : PressureSensor;
        part pressureSensorDischarge : PressureSensor;
        part temperatureSensor : TemperatureSensor;
        part speedSensor : SpeedSensor;
        part controller : PumpController;
        part baseplate : Baseplate;
        part containmentDrain : LeakageContainment;

        connect suction to inletStrainer.inlet;
        connect inletStrainer.outlet to isolationValve.inlet;
        connect isolationValve.outlet to pump.inlet;
        connect pump.outlet to checkValve.inlet;
        connect checkValve.outlet to discharge;
        connect pump.bypassOutlet to reliefValve.inlet;
        connect reliefValve.outlet to pump.inlet;
        connect electricalSupply to driveMotor.electricalInput;
        connect driveMotor.shaftOutput to coupling.inputShaft;
        connect coupling.outputShaft to pump.shaftInput;
        connect pump.caseDrain to containmentDrain.inlet;
        connect containmentDrain.outlet to drain;
        connect pump.thermalOutput to heatRejection;
        connect command to controller.commandInput;
        connect controller.motorCommand to driveMotor.controlInput;
        connect pressureSensorInlet.sensedPort to pump.inlet;
        connect pressureSensorDischarge.sensedPort to pump.outlet;
        connect temperatureSensor.sensedPort to pump.thermalOutput;
        connect speedSensor.sensedShaft to coupling.outputShaft;
        connect controller.statusOutput to status;

        constraint flowContinuity {
            discharge.flowRate == pump.actualFlow - drain.leakageFlow;
        }

        constraint pressureProtection {
            discharge.staticPressure <= maximumDischargePressure;
        }

        constraint inletProtection {
            suction.staticPressure >= minimumInletPressure;
        }

        constraint speedLimit {
            pump.shaftInput.rotationSpeed <= maximumSpeed;
        }

        constraint thermalLimit {
            heatRejection.casingTemperature <= maximumFluidTemperature;
        }

        perform action operateSubsystem : PumpingSubsystemOperation;
        exhibit state operatingStates : PumpingSubsystemStates;
    }

    part def RotaryVanePump {
        attribute camRingEccentricity : Real = 0.0018;
        attribute vaneCount : Integer = 8;
        attribute rotorDiameter : ISQ::length = 0.072;
        attribute rotorWidth : ISQ::length = 0.038;
        attribute nominalClearance : ISQ::length = 0.000035;
        attribute actualFlow : FlowRate;
        attribute pressureRise : Pressure;
        attribute casingTemperature : Temperature;
        attribute slipFlow : FlowRate;
        attribute hydraulicPower : Power;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port shaftInput : MechanicalDrivePort;
        port bypassOutlet : FluidOutletPort;
        port caseDrain : LeakageDrainPort;
        port thermalOutput : ThermalPort;

        part rotor : Rotor;
        part vanes[8] : SlidingVane;
        part camRing : CamRing;
        part inletPortPlate : PortPlate;
        part outletPortPlate : PortPlate;
        part shaftSeal : MechanicalSeal;
        part bearings[2] : Bearing;
        part casing : PumpCasing;

        constraint displacementFlow {
            actualFlow == shaftInput.rotationSpeed * 0.00000165 * 0.88 / 6.283185307;
        }

        constraint pressureRiseCalculation {
            pressureRise == outlet.staticPressure - inlet.staticPressure;
        }

        constraint hydraulicPowerCalculation {
            hydraulicPower == pressureRise * actualFlow;
        }

        constraint sealLeakageLimit {
            caseDrain.leakageFlow <= 0.00000003;
        }

        perform action compressAndDisplaceFluid : RotaryVanePumpingAction;
    }

    part def Rotor {
        attribute diameter : ISQ::length = 0.072;
        attribute width : ISQ::length = 0.038;
        attribute slotCount : Integer = 8;
        attribute material : String = "hardened stainless steel";
    }

    part def SlidingVane {
        attribute radialTravel : ISQ::length = 0.0035;
        attribute thickness : ISQ::length = 0.003;
        attribute tipWearLimit : ISQ::length = 0.0004;
        attribute material : String = "carbon graphite composite";
    }

    part def CamRing {
        attribute boreDiameter : ISQ::length = 0.079;
        attribute eccentricity : ISQ::length = 0.0018;
        attribute material : String = "nitrided steel";
    }

    part def PortPlate {
        attribute portArea : ISQ::area = 0.00016;
        attribute wearAllowance : ISQ::length = 0.0002;
    }

    part def MechanicalSeal {
        attribute maximumSealPressure : Pressure = 1200000;
        attribute maximumLeakage : FlowRate = 0.00000003;
        attribute sealFaceMaterial : String = "silicon carbide";
    }

    part def Bearing {
        attribute designLifeHours : Real = 20000;
        attribute maximumRadialLoad : ISQ::force = 1100;
        attribute lubricationType : String = "sealed grease";
    }

    part def PumpCasing {
        attribute maximumAllowableWorkingPressure : Pressure = 1500000;
        attribute hydrostaticTestPressure : Pressure = 2250000;
        attribute material : String = "ductile iron";
    }

    part def ElectricMotor {
        attribute ratedPower : Power = 2200;
        attribute ratedSpeed : AngularSpeed = 183.26;
        attribute efficiency : Real = 0.91;
        attribute insulationClass : String = "Class F";
        attribute windingTemperature : Temperature;

        port electricalInput : ElectricalInputPort;
        port shaftOutput : MechanicalDrivePort;
        port controlInput : CommandPort;

        constraint motorPowerLimit {
            shaftOutput.power <= ratedPower * efficiency;
        }
    }

    part def FlexibleCoupling {
        attribute torsionalStiffness : Real = 820;
        attribute maximumTorque : Torque = 18.5;
        attribute misalignmentCapacity : ISQ::length = 0.0005;

        port inputShaft : MechanicalDrivePort;
        port outputShaft : MechanicalDrivePort;

        constraint torqueTransfer {
            outputShaft.transmittedTorque <= maximumTorque;
        }
    }

    part def InternalBypassReliefValve {
        attribute setPressure : Pressure = 1100000;
        attribute fullBypassPressure : Pressure = 1250000;
        attribute bypassFlowCapacity : FlowRate = 0.0035;
        attribute crackingPressureTolerance : Pressure = 50000;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        exhibit state reliefValveStates : ReliefValveStates;
    }

    part def DischargeCheckValve {
        attribute crackingPressure : Pressure = 12000;
        attribute reverseLeakageLimit : FlowRate = 0.00000005;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def InletStrainer {
        attribute meshSize : ISQ::length = 0.000125;
        attribute cleanPressureDrop : Pressure = 8000;
        attribute cloggedPressureDropLimit : Pressure = 35000;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def ManualIsolationValve {
        attribute open : Boolean = true;
        attribute pressureRating : Pressure = 1600000;
        attribute boreDiameter : ISQ::length = 0.025;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def PressureSensor {
        attribute rangeMinimum : Pressure = 0;
        attribute rangeMaximum : Pressure = 1600000;
        attribute accuracy : Pressure = 4000;
        attribute measuredPressure : Pressure;

        port sensedPort : FluidInletPort;
    }

    part def TemperatureSensor {
        attribute rangeMinimum : Temperature = 253.15;
        attribute rangeMaximum : Temperature = 423.15;
        attribute accuracy : Temperature = 1.0;
        attribute measuredTemperature : Temperature;

        port sensedPort : ThermalPort;
    }

    part def SpeedSensor {
        attribute rangeMaximum : AngularSpeed = 314.16;
        attribute accuracy : AngularSpeed = 1.0;
        attribute measuredSpeed : AngularSpeed;

        port sensedShaft : MechanicalDrivePort;
    }

    part def PumpController {
        attribute startDelay : ISQ::time = 1.5;
        attribute primeTimeout : ISQ::time = 8.0;
        attribute shutdownRampTime : ISQ::time = 3.0;
        attribute commandedSpeed : AngularSpeed;
        attribute detectedFault : FaultCode = FaultCode::none;

        port commandInput : CommandPort;
        port motorCommand : CommandPort;
        port statusOutput : StatusPort;

        perform action supervisePump : PumpControlAction;
    }

    part def Baseplate {
        attribute mass : ISQ::mass = 42;
        attribute flatnessTolerance : ISQ::length = 0.00025;
        attribute material : String = "painted carbon steel";
    }

    part def LeakageContainment {
        attribute sumpVolume : Volume = 0.0015;
        attribute highLevelTripVolume : Volume = 0.0012;

        port inlet : LeakageDrainPort;
        port outlet : LeakageDrainPort;
    }

    action def PumpingSubsystemOperation {
        in item command : ControlCommand;
        in item inletFluid : ProcessFluid;
        out item outletFluid : ProcessFluid;
        out item status : PumpStatus;

        first start;
        then validateCommand;
        then primePump;
        then regulateFlow;
        then monitorProtection;
        then stopWhenDisabled;

        action start;
        action validateCommand;
        action primePump;
        action regulateFlow;
        action monitorProtection;
        action stopWhenDisabled;
    }

    action def RotaryVanePumpingAction {
        in item inletFluid : ProcessFluid;
        in shaftSpeed : AngularSpeed;
        in inletPressure : Pressure;
        out item pressurizedFluid : ProcessFluid;
        out outletPressure : Pressure;
        out deliveredFlow : FlowRate;

        action fillExpandingChambers;
        action trapFluidBetweenAdjacentVanes;
        action reduceChamberVolumeByCamRingEccentricity;
        action dischargePressurizedFluid;
        action bypassExcessPressure;
        action rejectHeatToCasing;

        first fillExpandingChambers;
        then trapFluidBetweenAdjacentVanes;
        then reduceChamberVolumeByCamRingEccentricity;
        then dischargePressurizedFluid;
        then bypassExcessPressure;
        then rejectHeatToCasing;
    }

    action def PumpControlAction {
        in item command : ControlCommand;
        in inletPressure : Pressure;
        in dischargePressure : Pressure;
        in casingTemperature : Temperature;
        in actualSpeed : AngularSpeed;
        out item motorCommand : ControlCommand;
        out item status : PumpStatus;

        action checkEnable;
        action checkInletPressure;
        action checkDischargePressure;
        action checkTemperature;
        action computeSpeedReference;
        action issueMotorCommand;
        action reportStatus;

        first checkEnable;
        then checkInletPressure;
        then checkDischargePressure;
        then checkTemperature;
        then computeSpeedReference;
        then issueMotorCommand;
        then reportStatus;
    }

    state def PumpingSubsystemStates {
        entry action initializeStatus;

        state Off;
        state Priming;
        state Running;
        state Bypassing;
        state Faulted;
        state Stopping;

        transition initial then Off;

        transition Off_to_Priming
            first Off
            accept ControlCommand
            if commandIn.enable and activeFault == FaultCode::none
            then Priming;

        transition Priming_to_Running
            first Priming
            if suction.staticPressure >= minimumInletPressure and pump.actualFlow > 0.0004
            then Running;

        transition Priming_to_Faulted
            first Priming
            if elapsedTime > 8.0 or suction.staticPressure < minimumInletPressure
            then Faulted;

        transition Running_to_Bypassing
            first Running
            if discharge.staticPressure >= internalReliefSetPressure
            then Bypassing;

        transition Bypassing_to_Running
            first Bypassing
            if discharge.staticPressure < internalReliefSetPressure - 75000
            then Running;

        transition Running_to_Faulted
            first Running
            if discharge.staticPressure > maximumDischargePressure
                or heatRejection.casingTemperature > maximumFluidTemperature
                or suction.staticPressure < minimumInletPressure
            then Faulted;

        transition Bypassing_to_Faulted
            first Bypassing
            if discharge.staticPressure > maximumDischargePressure
                or heatRejection.casingTemperature > maximumFluidTemperature
            then Faulted;

        transition Running_to_Stopping
            first Running
            accept ControlCommand
            if not commandIn.enable
            then Stopping;

        transition Bypassing_to_Stopping
            first Bypassing
            accept ControlCommand
            if not commandIn.enable
            then Stopping;

        transition Stopping_to_Off
            first Stopping
            if actualSpeed <= 1.0
            then Off;

        transition Faulted_to_Off
            first Faulted
            accept ControlCommand
            if commandIn.resetFault
            then Off;
    }

    state def ReliefValveStates {
        state Closed;
        state Cracking;
        state OpenBypass;

        transition initial then Closed;

        transition Closed_to_Cracking
            first Closed
            if inlet.staticPressure >= setPressure
            then Cracking;

        transition Cracking_to_OpenBypass
            first Cracking
            if inlet.staticPressure >= fullBypassPressure
            then OpenBypass;

        transition Cracking_to_Closed
            first Cracking
            if inlet.staticPressure < setPressure - 50000
            then Closed;

        transition OpenBypass_to_Cracking
            first OpenBypass
            if inlet.staticPressure < fullBypassPressure - 50000
            then Cracking;
    }

    requirement def PumpingSubsystemRequirement {
        subject subsystem : RotaryVanePumpingSubsystem;
    }

    requirement continuousFluidTransfer : PumpingSubsystemRequirement {
        doc
        /* The subsystem shall transfer compatible process fluid from the suction interface to the discharge interface using a rotary vane pump when enabled. */

        require constraint {
            subsystem.operatingMode == PumpOperatingMode::running implies subsystem.discharge.flowRate >= 0.0025;
        }
    }

    requirement dischargePressureCapability : PumpingSubsystemRequirement {
        doc
        /* The subsystem shall provide at least 900 kPa discharge pressure at rated flow for fluid viscosity between 0.001 Pa*s and 0.12 Pa*s. */

        require constraint {
            subsystem.discharge.staticPressure >= subsystem.ratedDischargePressure;
        }
    }

    requirement overPressureProtection : PumpingSubsystemRequirement {
        doc
        /* The subsystem shall limit discharge pressure by internal bypass relief before casing pressure exceeds the maximum allowable operating pressure. */

        require constraint {
            subsystem.discharge.staticPressure <= subsystem.maximumDischargePressure;
        }
    }

    requirement dryRunProtection : PumpingSubsystemRequirement {
        doc
        /* The controller shall transition the subsystem to a faulted state when inlet pressure falls below the minimum allowable inlet pressure during priming or running. */

        require constraint {
            subsystem.suction.staticPressure < subsystem.minimumInletPressure implies subsystem.activeFault == FaultCode::lowInletPressure;
        }
    }

    requirement thermalProtection : PumpingSubsystemRequirement {
        doc
        /* The subsystem shall stop pumping and report a fault if casing temperature exceeds the maximum allowable fluid temperature. */

        require constraint {
            subsystem.heatRejection.casingTemperature > subsystem.maximumFluidTemperature implies subsystem.activeFault == FaultCode::overTemperature;
        }
    }

    requirement leakageContainmentRequirement : PumpingSubsystemRequirement {
        doc
        /* Shaft seal leakage shall be routed to the containment drain and shall not exceed the specified continuous leakage rate during normal operation. */

        require constraint {
            subsystem.drain.leakageFlow <= 0.00000003;
        }
    }

    requirement commandAndStatusRequirement : PumpingSubsystemRequirement {
        doc
        /* The subsystem shall accept enable, speed, mode, and reset commands and shall report mode, speed, pressure, flow, readiness, and fault status. */

        require constraint {
            subsystem.status.statusOut.actualMode == subsystem.operatingMode;
        }
    }

    requirement reverseFlowPrevention : PumpingSubsystemRequirement {
        doc
        /* The discharge check valve shall prevent reverse flow from the discharge interface to the pump outlet when the pump is stopped. */

        require constraint {
            subsystem.operatingMode == PumpOperatingMode::off implies subsystem.checkValve.reverseLeakageLimit <= 0.00000005;
        }
    }

    requirement speedControlRequirement : PumpingSubsystemRequirement {
        doc
        /* The motor controller shall limit commanded rotary vane pump shaft speed to the maximum permitted pump speed. */

        require constraint {
            subsystem.controller.commandedSpeed <= subsystem.maximumSpeed;
        }
    }

    satisfy continuousFluidTransfer by RotaryVanePumpingSubsystem;
    satisfy dischargePressureCapability by RotaryVanePumpingSubsystem;
    satisfy overPressureProtection by InternalBypassReliefValve;
    satisfy dryRunProtection by PumpController;
    satisfy thermalProtection by PumpController;
    satisfy leakageContainmentRequirement by LeakageContainment;
    satisfy commandAndStatusRequirement by PumpController;
    satisfy reverseFlowPrevention by DischargeCheckValve;
    satisfy speedControlRequirement by PumpController;

}