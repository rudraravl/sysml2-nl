package SolenoidActuatorSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Voltage :> ISQ::electromagnetic::ElectricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electromagnetic::ElectricCurrent {
        unit = SI::ampere;
    }

    attribute def Resistance :> ISQ::electromagnetic::ElectricResistance {
        unit = SI::ohm;
    }

    attribute def Inductance :> ISQ::electromagnetic::Inductance {
        unit = SI::henry;
    }

    attribute def Force :> ISQ::mechanics::Force {
        unit = SI::newton;
    }

    attribute def Position :> ISQ::mechanics::Length {
        unit = SI::millimetre;
    }

    attribute def Temperature :> ISQ::thermodynamics::ThermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def TimeDuration :> ISQ::time::Time {
        unit = SI::second;
    }

    attribute def DutyCycle {
        :>> range = "0..1";
    }

    enum def CommandState {
        enum off;
        enum energize;
        enum hold;
        enum release;
    }

    enum def PlungerState {
        enum extended;
        enum movingToRetracted;
        enum retracted;
        enum movingToExtended;
        enum fault;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def MagneticFlux {
        attribute fluxDensity;
        attribute direction;
    }

    item def LinearMotion {
        attribute displacement : Position;
        attribute force : Force;
        attribute velocity;
    }

    item def ControlCommand {
        attribute requestedState : CommandState;
        attribute requestedDutyCycle : DutyCycle;
    }

    port def ElectricalPowerPort {
        in item powerIn : ElectricalPower;
    }

    port def ControlPort {
        in item command : ControlCommand;
    }

    port def MotionOutputPort {
        out item motion : LinearMotion;
    }

    port def ThermalPort {
        out attribute coilTemperature : Temperature;
    }

    action def ApplyDriveVoltage {
        in attribute supplyVoltage : Voltage;
        in attribute command : CommandState;
        out attribute coilVoltage : Voltage;
    }

    action def GenerateMagneticField {
        in attribute coilCurrent : Current;
        in attribute turns;
        out item magneticField : MagneticFlux;
    }

    action def MovePlunger {
        in item magneticField : MagneticFlux;
        in attribute springForce : Force;
        out item linearMotion : LinearMotion;
    }

    action def RemoveDrive {
        in attribute command : CommandState;
        out attribute coilVoltage : Voltage;
    }

    action def MonitorTemperature {
        in attribute coilTemperature : Temperature;
        out attribute overTemperature;
    }

    part def DCDriver {
        port powerPort : ElectricalPowerPort;
        port controlPort : ControlPort;
        port coilOutput : ElectricalPowerPort;

        attribute inputVoltage : Voltage = 24 [SI::volt];
        attribute maxOutputCurrent : Current = 2.0 [SI::ampere];
        attribute pwmDutyCycle : DutyCycle = 0.0;
        attribute switchingFrequency = 20000;

        action drive : ApplyDriveVoltage;
    }

    part def Coil {
        port electricalInput : ElectricalPowerPort;
        port thermalOutput : ThermalPort;

        attribute resistance : Resistance = 12 [SI::ohm];
        attribute inductance : Inductance = 0.045 [SI::henry];
        attribute turns = 850;
        attribute ratedVoltage : Voltage = 24 [SI::volt];
        attribute steadyStateCurrent : Current = 2.0 [SI::ampere];
        attribute maximumTemperature : Temperature = 105 [SI::degreeCelsius];
        attribute currentTemperature : Temperature = 25 [SI::degreeCelsius];

        action createField : GenerateMagneticField;
        action monitorHeat : MonitorTemperature;
    }

    part def MagneticCore {
        attribute material = "low carbon steel";
        attribute relativePermeability = 1800;
        attribute poleFaceArea;
        attribute airGap : Position = 4 [SI::millimetre];

        port fieldInput {
            in item field : MagneticFlux;
        }

        port fieldOutput {
            out item concentratedField : MagneticFlux;
        }
    }

    part def Plunger {
        port motionOutput : MotionOutputPort;

        attribute mass;
        attribute strokeLength : Position = 8 [SI::millimetre];
        attribute currentPosition : Position = 8 [SI::millimetre];
        attribute retractedPosition : Position = 0 [SI::millimetre];
        attribute extendedPosition : Position = 8 [SI::millimetre];
        attribute pullInForce : Force = 18 [SI::newton];
        attribute holdingForce : Force = 32 [SI::newton];

        action translate : MovePlunger;
    }

    part def ReturnSpring {
        attribute preloadForce : Force = 4 [SI::newton];
        attribute springRate;
        attribute maximumCompression : Position = 8 [SI::millimetre];

        port springForceOutput {
            out attribute springForce : Force;
        }
    }

    part def MechanicalLoadInterface {
        port actuatorInput : MotionOutputPort;

        attribute requiredStroke : Position = 6 [SI::millimetre];
        attribute maximumLoadForce : Force = 12 [SI::newton];
    }

    part def SolenoidActuator {
        port supply : ElectricalPowerPort;
        port commandInput : ControlPort;
        port mechanicalOutput : MotionOutputPort;
        port thermalStatus : ThermalPort;

        part driver : DCDriver;
        part coil : Coil;
        part core : MagneticCore;
        part plunger : Plunger;
        part returnSpring : ReturnSpring;

        attribute nominalVoltage : Voltage = 24 [SI::volt];
        attribute ratedCurrent : Current = 2.0 [SI::ampere];
        attribute pullInTime : TimeDuration = 0.035 [SI::second];
        attribute releaseTime : TimeDuration = 0.025 [SI::second];
        attribute continuousDutyCycle : DutyCycle = 0.35;
        attribute primaryFunction = "Convert controlled electrical energy into short-stroke linear mechanical motion.";

        connect supply to driver.powerPort;
        connect commandInput to driver.controlPort;
        connect driver.coilOutput to coil.electricalInput;
        connect coil.thermalOutput to thermalStatus;
        connect plunger.motionOutput to mechanicalOutput;

        state def OperationalStateMachine {
            state deEnergized;
            state energizing;
            state actuated;
            state holding;
            state releasing;
            state thermalFault;

            entry; then deEnergized;

            transition deEnergized_to_energizing
                first deEnergized
                accept ControlCommand
                if command.requestedState == CommandState::energize
                do driver.drive
                then energizing;

            transition energizing_to_actuated
                first energizing
                if plunger.currentPosition <= plunger.retractedPosition
                do plunger.translate
                then actuated;

            transition actuated_to_holding
                first actuated
                accept ControlCommand
                if command.requestedState == CommandState::hold
                then holding;

            transition holding_to_releasing
                first holding
                accept ControlCommand
                if command.requestedState == CommandState::release or command.requestedState == CommandState::off
                do RemoveDrive
                then releasing;

            transition releasing_to_deEnergized
                first releasing
                if plunger.currentPosition >= plunger.extendedPosition
                then deEnergized;

            transition any_to_thermalFault
                first deEnergized
                if coil.currentTemperature > coil.maximumTemperature
                do coil.monitorHeat
                then thermalFault;

            transition thermalFault_to_deEnergized
                first thermalFault
                accept ControlCommand
                if command.requestedState == CommandState::off and coil.currentTemperature < 80 [SI::degreeCelsius]
                then deEnergized;
        }

        perform OperationalStateMachine;
    }

    part def SolenoidBasedSystem {
        port externalPower : ElectricalPowerPort;
        port externalCommand : ControlPort;
        port actuatorMotion : MotionOutputPort;

        part solenoid : SolenoidActuator;
        part loadInterface : MechanicalLoadInterface;

        attribute systemName = "Electromagnetic Linear Solenoid Actuation System";
        attribute highLevelPrimaryFunction = "Receive an electrical command and move a mechanical load between extended and retracted positions using a solenoid-generated magnetic field.";

        connect externalPower to solenoid.supply;
        connect externalCommand to solenoid.commandInput;
        connect solenoid.mechanicalOutput to loadInterface.actuatorInput;
        connect solenoid.mechanicalOutput to actuatorMotion;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : SolenoidBasedSystem;

        doc /* The system shall convert an external electrical control command into linear mechanical actuation by energizing a solenoid coil, generating a magnetic field, retracting a plunger, and transferring motion to a mechanical load interface. */

        require constraint {
            system.solenoid.nominalVoltage == 24 [SI::volt]
        }

        require constraint {
            system.solenoid.plunger.strokeLength >= system.loadInterface.requiredStroke
        }

        require constraint {
            system.solenoid.plunger.pullInForce > system.loadInterface.maximumLoadForce
        }
    }

    requirement def ElectricalCompatibilityRequirement {
        subject actuator : SolenoidActuator;

        doc /* The solenoid actuator shall operate from a 24 V DC supply and limit coil current to its rated value during steady-state operation. */

        require constraint {
            actuator.nominalVoltage == actuator.coil.ratedVoltage
        }

        require constraint {
            actuator.ratedCurrent <= actuator.driver.maxOutputCurrent
        }
    }

    requirement def MotionRequirement {
        subject actuator : SolenoidActuator;

        doc /* The solenoid actuator shall retract the plunger within the specified pull-in time and return it to the extended position after removal of drive voltage. */

        require constraint {
            actuator.pullInTime <= 0.050 [SI::second]
        }

        require constraint {
            actuator.releaseTime <= 0.040 [SI::second]
        }

        require constraint {
            actuator.plunger.extendedPosition - actuator.plunger.retractedPosition == actuator.plunger.strokeLength
        }
    }

    requirement def ThermalProtectionRequirement {
        subject actuator : SolenoidActuator;

        doc /* The solenoid actuator shall monitor coil temperature and enter a fault state when the maximum allowed coil temperature is exceeded. */

        require constraint {
            actuator.coil.currentTemperature <= actuator.coil.maximumTemperature
        }

        require constraint {
            actuator.continuousDutyCycle <= 0.35
        }
    }

    satisfy PrimaryFunctionRequirement by SolenoidBasedSystem;
    satisfy ElectricalCompatibilityRequirement by SolenoidActuator;
    satisfy MotionRequirement by SolenoidActuator;
    satisfy ThermalProtectionRequirement by SolenoidActuator;
}