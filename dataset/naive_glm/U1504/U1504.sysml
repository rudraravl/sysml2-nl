package SolenoidActuatorSystem {

    import ScalarValues::*;

    // ==================== Value Type Definitions ====================

    value def Voltage :> Real {
        doc "Electrical potential difference in volts (V)";
    }

    value def Current :> Real {
        doc "Electric current in amperes (A)";
    }

    value def Resistance :> Real {
        doc "Electrical resistance in ohms";
    }

    value def Power :> Real {
        doc "Electrical power in watts (W)";
    }

    value def Inductance :> Real {
        doc "Electrical inductance in henries (H)";
    }

    value def Force :> Real {
        doc "Mechanical force in newtons (N)";
    }

    value def Displacement :> Real {
        doc "Linear displacement in millimeters (mm)";
    }

    value def TimeDuration :> Real {
        doc "Time duration in milliseconds (ms)";
    }

    value def MagneticFluxDensity :> Real {
        doc "Magnetic flux density in teslas (T)";
    }

    value def SpringRate :> Real {
        doc "Spring stiffness in newtons per millimeter (N/mm)";
    }

    value def Temperature :> Real {
        doc "Temperature in degrees Celsius";
    }

    value def CycleCount :> Integer {
        doc "Number of actuation cycles";
    }

    value def Mass :> Real {
        doc "Mass in kilograms (kg)";
    }

    // ==================== Enumeration Definitions ====================

    enum def CommandKind {
        activate;
        deactivate;
    }

    enum def SolenoidMode {
        inactive;
        energizing;
        extended;
        retracting;
        faulted;
    }

    enum def HealthStatus {
        healthy;
        degraded;
        failed;
    }

    // ==================== Item Definitions ====================

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute energized : Boolean;
    }

    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensity;
        attribute fieldIntensity : Real;
    }

    item def MechanicalMotion {
        attribute force : Force;
        attribute position : Displacement;
        attribute velocity : Real;
    }

    item def CommandSignal {
        attribute command : CommandKind;
        attribute timestamp : TimeDuration;
    }

    // ==================== Port Definitions ====================

    port def PowerInPort {
        in power : ElectricalPower;
        attribute nominalVoltage : Voltage = 24.0;
    }

    port def PowerOutPort {
        out power : ElectricalPower;
        attribute nominalVoltage : Voltage = 24.0;
    }

    port def MagneticOutPort {
        out field : MagneticField;
    }

    port def MagneticInPort {
        in field : MagneticField;
    }

    port def MechanicalOutPort {
        out motion : MechanicalMotion;
        attribute maxStroke : Displacement = 12.0;
    }

    port def MechanicalInPort {
        in motion : MechanicalMotion;
    }

    port def SpringCouplingPort {
        inout motion : MechanicalMotion;
    }

    port def ControlInPort {
        in signal : CommandSignal;
    }

    port def StatusOutPort {
        out mode : SolenoidMode;
        out cycleCount : CycleCount;
        out faultCode : Integer;
    }

    // ==================== Part Definitions ====================

    part def FerromagneticHousing {
        doc "Protective ferromagnetic steel housing enclosing all internal solenoid components";

        attribute material : String = "Ferromagnetic Steel";
        attribute wallThickness : Displacement = 2.0;
        attribute magneticPermeability : Real = 200.0;
        attribute maxTemperature : Temperature = 150.0;
        attribute ingressProtection : String = "IP54";
        attribute overallLength : Displacement = 45.0;
        attribute outerDiameter : Displacement = 25.0;
        attribute mountingType : String = "Flange mount";

        action def ShieldField {
            doc "Housing redirects magnetic flux through internal components";
            in externalField : MagneticFluxDensity;
            out internalField : MagneticFluxDensity;
        }
    }

    part def ElectromagneticCoil {
        doc "24V electromagnetic coil generating magnetic field when energized";

        attribute nominalVoltage : Voltage = 24.0;
        attribute nominalCurrent : Current = 1.5;
        attribute coilResistance : Resistance = 16.0;
        attribute turns : Integer = 400;
        attribute inductance : Inductance = 0.025;
        attribute maxPowerDissipation : Power = 40.0;
        attribute wireGauge : String = "AWG 24";
        attribute bobbinMaterial : String = "Nylon 6/6";
        attribute isEnergized : Boolean = false;
        attribute generatedFluxDensity : MagneticFluxDensity = 0.0;
        attribute windingResistance : Resistance = 16.0;
        attribute thermalResistance : Real = 8.5;

        port electricalInput : PowerInPort;
        port magneticOutput : MagneticOutPort;

        action energize {
            doc "Energizes the coil with supplied voltage, generating magnetic field";
            in supplyVoltage : Voltage;
            in supplyCurrent : Current;
            out fieldStrength : MagneticFluxDensity;
        }

        action deenergize {
            doc "De-energizes the coil, collapsing the magnetic field";
            out decayedField : MagneticFluxDensity;
        }

        action dissipateHeat {
            doc "Dissipates resistive heating during energization";
            in powerDissipated : Power;
            out temperatureRise : Temperature;
        }
    }

    part def Plunger {
        doc "Movable magnetic rod providing 12mm linear stroke and output force";

        attribute material : String = "Soft Magnetic Stainless 430F";
        attribute mass : Mass = 0.035;
        attribute strokeLength : Displacement = 12.0;
        attribute diameter : Displacement = 6.0;
        attribute maxOutputForce : Force = 35.0;
        attribute currentForce : Force = 0.0;
        attribute currentDisplacement : Displacement = 0.0;
        attribute currentVelocity : Real = 0.0;
        attribute surfaceFinish : String = "Polished";
        attribute magneticPermeability : Real = 5000.0;

        port magneticInput : MagneticInPort;
        port springInterface : SpringCouplingPort;
        port mechanicalOutput : MechanicalOutPort;

        action extend {
            doc "Plunger moves from rest to extended position under magnetic force";
            in magneticForce : Force;
            out finalDisplacement : Displacement;
        }

        action retract {
            doc "Plunger returns from extended to rest position under spring force";
            in springForce : Force;
            out finalDisplacement : Displacement;
        }

        action hold {
            doc "Plunger maintains extended position against external load";
            in holdingForce : Force;
        }

        action sensePosition {
            doc "Reports current plunger displacement";
            out position : Displacement;
        }
    }

    part def ReturnSpring {
        doc "Compression spring returning plunger to rest when coil de-energized";

        attribute springConstant : SpringRate = 2.5;
        attribute freeLength : Displacement = 25.0;
        attribute installedLength : Displacement = 13.0;
        attribute maxDeflection : Displacement = 12.0;
        attribute preloadForce : Force = 5.0;
        attribute material : String = "Music Wire ASTM A228";
        attribute wireDiameter : Displacement = 1.2;
        attribute activeCoils : Integer = 18;
        attribute surfaceCoating : String = "Zinc-plated";
        attribute fatigueLife : CycleCount = 5000000;

        port plungerInterface : SpringCouplingPort;

        action compress {
            doc "Spring compresses as plunger extends, storing energy";
            in plungerDisplacement : Displacement;
            out storedForce : Force;
        }

        action expand {
            doc "Spring expands, releasing stored energy to return plunger";
            in currentDisplacement : Displacement;
            out returnForce : Force;
        }

        action maintainRest {
            doc "Spring holds plunger at rest position with preload force";
            out restForce : Force;
        }
    }

    part def Controller {
        doc "Controller managing solenoid activation/deactivation and cycle monitoring";

        attribute currentMode : SolenoidMode = inactive;
        attribute cycleCounter : CycleCount = 0;
        attribute maxCycles : CycleCount = 2000000;
        attribute actuationTimeLimit : TimeDuration = 40.0;
        attribute lastActuationTime : TimeDuration = 0.0;
        attribute activationStartTime : TimeDuration = 0.0;
        attribute isHealthy : Boolean = true;
        attribute faultCode : Integer = 0;
        attribute supplyVoltage : Voltage = 0.0;
        attribute supplyCurrent : Current = 0.0;
        attribute health : HealthStatus = healthy;

        port powerInput : PowerInPort;
        port powerOutput : PowerOutPort;
        port controlInput : ControlInPort;
        port statusOutput : StatusOutPort;

        action handleActivate {
            doc "Processes activation command and energizes coil";
            in cmd : CommandSignal;
            out coilPower : ElectricalPower;
        }

        action handleDeactivate {
            doc "Processes deactivation command and de-energizes coil";
            in cmd : CommandSignal;
            out coilPower : ElectricalPower;
        }

        action recordCycle {
            doc "Records completion of one full actuation cycle";
            out count : CycleCount;
        }

        action checkHealth {
            doc "Checks system health and updates fault status";
            out status : HealthStatus;
            out code : Integer;
        }

        action measureActuationTime {
            doc "Measures elapsed time during plunger extension";
            in startTime : TimeDuration;
            in endTime : TimeDuration;
            out duration : TimeDuration;
        }

        state ControllerStateMachine {
            entry state Idle {
                entry { currentMode = inactive; }
            }

            state Activating {
                entry { currentMode = energizing; }
            }

            state Holding {
                entry { currentMode = extended; }
            }

            state Retracting {
                entry { currentMode = retracting; }
            }

            state Fault {
                entry { currentMode = faulted; }
            }

            transition from Idle to Activating
                when controlInput.signal.command == activate;

            transition from Activating to Holding
                when lastActuationTime < actuationTimeLimit;

            transition from Holding to Retracting
                when controlInput.signal.command == deactivate;

            transition from Retracting to Idle
                when currentMode == inactive;

            transition from Activating to Fault
                when lastActuationTime >= actuationTimeLimit;
        }
    }

    // ==================== Connection Definitions ====================

    connection def ElectricalPowerLink {
        end source : PowerOutPort;
        end sink : PowerInPort;
    }

    connection def MagneticFieldLink {
        end source : MagneticOutPort;
        end sink : MagneticInPort;
    }

    connection def MechanicalOutputLink {
        end source : MechanicalOutPort;
        end sink : MechanicalInPort;
    }

    connection def SpringCouplingLink {
        end plungerSide : SpringCouplingPort;
        end springSide : SpringCouplingPort;
    }

    connection def ControlSignalLink {
        end source : ControlInPort;
        end sink : ControlInPort;
    }

    // ==================== Top-Level System Definition ====================

    part def SolenoidActuator {
        doc "Electromechanical solenoid actuator converting 24V DC electrical energy into 12mm linear mechanical motion";

        port powerInput : PowerInPort;
        port commandInput : ControlInPort;
        port mechanicalOutput : MechanicalOutPort;
        port statusOutput : StatusOutPort;

        part housing : FerromagneticHousing {
            doc "Ferromagnetic steel protective enclosure";
        }

        part coil : ElectromagneticCoil {
            doc "24V electromagnetic coil generating actuation field";
        }

        part plunger : Plunger {
            doc "Magnetic plunger with 12mm stroke";
        }

        part returnSpring : ReturnSpring {
            doc "Return compression spring for plunger reset";
        }

        part controller : Controller {
            doc "Solenoid activation controller";
        }

        connection powerToController from powerInput to controller.powerInput;
        connection controllerToCoil from controller.powerOutput to coil.electricalInput;
        connection coilToPlunger from coil.magneticOutput to plunger.magneticInput;
        connection plungerToSpring from plunger.springInterface to returnSpring.plungerInterface;
        connection plungerToOutput from plunger.mechanicalOutput to mechanicalOutput;
        connection commandToController from commandInput to controller.controlInput;
        connection statusFromController from controller.statusOutput to statusOutput;

        state ActuationStateMachine {
            entry state Deenergized {
                doc "System at rest, plunger at home position, no coil current";
            }

            state Energizing {
                doc "Coil energized at 24V, plunger accelerating toward extended position";
            }

            state FullyExtended {
                doc "Plunger at full 12mm stroke, holding against mechanical load";
            }

            state Retracting {
                doc "Coil de-energized, return spring pushing plunger back to rest";
            }

            transition from Deenergized to Energizing
                when commandInput.signal.command == activate;

            transition from Energizing to FullyExtended
                when plunger.currentDisplacement >= plunger.strokeLength;

            transition from FullyExtended to Retracting
                when commandInput.signal.command == deactivate;

            transition from Retracting to Deenergized
                when plunger.currentDisplacement <= 0.0;
        }
    }

    // ==================== Requirement Definitions ====================

    requirement def CoilVoltageRequirement {
        doc "The electromagnetic coil shall operate at 24V DC nominal supply voltage";
        subject actuator : SolenoidActuator;
        objective {
            actuator.coil.nominalVoltage == 24.0
        }
    }

    requirement def StrokeLengthRequirement {
        doc "The plunger shall produce a 12mm linear stroke when fully actuated";
        subject actuator : SolenoidActuator;
        objective {
            actuator.plunger.strokeLength == 12.0
        }
    }

    requirement def ActuationTimeRequirement {
        doc "The plunger shall reach full extension in under 40 milliseconds upon activation";
        subject actuator : SolenoidActuator;
        objective {
            actuator.controller.actuationTimeLimit <= 40.0
        }
    }

    requirement def ReturnSpringRequirement {
        doc "When electrical power is off, the return spring shall push the plunger to its original resting position";
        subject actuator : SolenoidActuator;
        objective {
            actuator.returnSpring.maxDeflection >= actuator.plunger.strokeLength
        }
    }

    requirement def HousingRequirement {
        doc "All internal components shall be encased in a protective ferromagnetic steel housing";
        subject actuator : SolenoidActuator;
        objective {
            actuator.housing.material == "Ferromagnetic Steel"
        }
    }

    requirement def CycleLifeRequirement {
        doc "The system shall be capable of performing at least 2 million actuation cycles";
        subject actuator : SolenoidActuator;
        objective {
            actuator.controller.maxCycles >= 2000000
        }
    }

    requirement def PowerConsumptionRequirement {
        doc "The system shall consume minimal electrical power during operation";
        subject actuator : SolenoidActuator;
        objective {
            actuator.coil.nominalVoltage * actuator.coil.nominalCurrent <= 40.0
        }
    }

    requirement def ControlInterfaceRequirement {
        doc "The system shall be controlled via simple activate and deactivate commands";
        subject actuator : SolenoidActuator;
        objective {
            actuator.commandInput.signal.command == activate or
            actuator.commandInput.signal.command == deactivate
        }
    }

    requirement def OutputForceRequirement {
        doc "The system shall generate sufficient output force to perform mechanical work";
        subject actuator : SolenoidActuator;
        objective {
            actuator.plunger.maxOutputForce >= 30.0
        }
    }

    requirement def MagneticFieldRequirement {
        doc "The energized coil shall generate sufficient magnetic field to move the plunger against spring and load forces";
        subject actuator : SolenoidActuator;
        objective {
            actuator.coil.generatedFluxDensity > 0.5
        }
    }

    requirement def ReliableOperationRequirement {
        doc "The system shall operate reliably throughout its design life with graceful fault handling";
        subject actuator : SolenoidActuator;
        objective {
            actuator.controller.isHealthy == true
        }
    }

    // ==================== Verification Definitions ====================

    verification def StrokeLengthVerification {
        doc "Verify the plunger achieves 12mm stroke under nominal load";
        subject actuator : SolenoidActuator;
        objective {
            actuator.plunger.currentDisplacement == 12.0
        }
    }

    verification def ActuationTimeVerification {
        doc "Verify full extension occurs within 40ms of activation";
        subject actuator : SolenoidActuator;
        objective {
            actuator.controller.lastActuationTime < 40.0
        }
    }

    verification def CycleEnduranceVerification {
        doc "Verify system withstands 2 million actuation cycles without failure";
        subject actuator : SolenoidActuator;
        objective {
            actuator.controller.cycleCounter >= 2000000
        }
    }

    verification def ReturnResetVerification {
        doc "Verify plunger returns to rest position upon deactivation";
        subject actuator : SolenoidActuator;
        objective {
            actuator.plunger.currentDisplacement == 0.0
        }
    }

    verification def PowerConsumptionVerification {
        doc "Verify power consumption remains within specified limits";
        subject actuator : SolenoidActuator;
        objective {
            actuator.coil.nominalVoltage * actuator.coil.nominalCurrent <= 40.0
        }
    }

    verification def HousingIntegrityVerification {
        doc "Verify housing integrity and material properties";
        subject actuator : SolenoidActuator;
        objective {
            actuator.housing.material == "Ferromagnetic Steel"
        }
    }

    // ==================== System Instance ====================

    part productionSolenoid : SolenoidActuator {
        doc "Production instance of the solenoid actuator system satisfying all requirements";

        satisfy CoilVoltageRequirement;
        satisfy StrokeLengthRequirement;
        satisfy ActuationTimeRequirement;
        satisfy ReturnSpringRequirement;
        satisfy HousingRequirement;
        satisfy CycleLifeRequirement;
        satisfy PowerConsumptionRequirement;
        satisfy ControlInterfaceRequirement;
        satisfy OutputForceRequirement;
        satisfy MagneticFieldRequirement;
        satisfy ReliableOperationRequirement;
    }
}
