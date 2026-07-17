package 'Solder System Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def SolderAlloyComposition {
        attribute tinContent : Real;
        attribute leadContent : Real;
        attribute silverContent : Real;
        attribute copperContent : Real;
        attribute fluxPercentage : Real;
    }

    attribute def MechanicalProperties {
        attribute tensileStrength : PressureValue;
        attribute shearStrength : PressureValue;
        attribute ductility : Real;
    }

    attribute def ThermalProperties {
        attribute meltingPoint : ThermodynamicTemperatureValue;
        attribute solidusTemperature : ThermodynamicTemperatureValue;
        attribute liquidusTemperature : ThermodynamicTemperatureValue;
        attribute thermalConductivity : Real;
    }

    item def SolderMaterial {
        attribute composition : SolderAlloyComposition;
        attribute thermalProps : ThermalProperties;
        attribute mechanicalProps : MechanicalProperties;
        attribute diameter : LengthValue;
        attribute length : LengthValue;
    }

    item def ElectricalComponent {
        attribute componentType : String;
        attribute leadCount : Integer;
        attribute leadDiameter : LengthValue;
    }

    item def CircuitBoard {
        attribute boardThickness : LengthValue;
        attribute copperThickness : LengthValue;
        attribute padDiameter : LengthValue;
    }

    item def SolderJoint {
        attribute jointStrength : ForceValue;
        attribute electricalResistance : Real;
        attribute jointQuality : Real;
        attribute isReliable : Boolean;
    }

    port def ThermalInterface {
        in temperature : ThermodynamicTemperatureValue;
        out heatTransfer : PowerValue;
    }

    port def ElectricalInterface {
        in voltage : ISQ::VoltageValue;
        out current : ISQ::ElectricCurrentValue;
    }

    attribute def StartSolderingSignal;
    attribute def ApplySolderSignal;
    attribute def ResetSignal;

    part def HeatingElement {
        attribute maxTemperature : ThermodynamicTemperatureValue;
        attribute powerRating : PowerValue;
        attribute heatingRate : Real;
        port thermalOutput : ThermalInterface;
        port powerInput : ElectricalInterface;
    }

    part def TemperatureSensor {
        attribute accuracy : ThermodynamicTemperatureValue;
        attribute responseTime : TimeValue;
        port sensing : ThermalInterface;
        out measuredTemp : ThermodynamicTemperatureValue;
    }

    part def ControllerUnit {
        attribute targetTemperature : ThermodynamicTemperatureValue;
        attribute temperatureTolerance : ThermodynamicTemperatureValue;
        in currentTemperature : ThermodynamicTemperatureValue;
        out powerCommand : PowerValue;
    }

    action def HeatToMeltingPoint {
        in targetTemp : ThermodynamicTemperatureValue;
        in currentTemp : ThermodynamicTemperatureValue;
        in heatingPower : PowerValue;
        out achievedTemp : ThermodynamicTemperatureValue;
        out heatingTime : TimeValue;
    }

    action def ApplySolderToJoint {
        in solderMaterial : SolderMaterial;
        in applicationRate : MassValue;
        in surfaceTemp : ThermodynamicTemperatureValue;
        out depositedMass : MassValue;
        out coverage : Real;
    }

    action def FormMetallurgicalBond {
        in depositedSolder : MassValue;
        in componentLead : ElectricalComponent;
        in boardPad : CircuitBoard;
        in bondingTemp : ThermodynamicTemperatureValue;
        out joint : SolderJoint;
    }

    action def CoolAndSolidify {
        in coolingRate : Real;
        in ambientTemp : ThermodynamicTemperatureValue;
        in initialTemp : ThermodynamicTemperatureValue;
        out finalTemp : ThermodynamicTemperatureValue;
        out solidificationTime : TimeValue;
    }

    action def InspectJointQuality {
        in joint : SolderJoint;
        in qualityThreshold : Real;
        out passed : Boolean;
        out defectType : String;
    }

    state def SolderingProcessState {
        in workingTemp : ThermodynamicTemperatureValue;
        
        entry; then idle;

        state idle {
            doc /* System is ready and waiting for soldering command */
        }
        
        transition idle_to_preheat
            first idle
            accept StartSolderingSignal
            then preheating;

        state preheating {
            doc /* Heating element brings tip to working temperature */
        }
        
        transition preheat_to_ready
            first preheating
            then ready;

        state ready {
            doc /* System at optimal temperature for soldering */
        }
        
        transition ready_to_applying
            first ready
            accept ApplySolderSignal
            then applying;

        state applying {
            doc /* Solder is being applied to the joint */
        }
        
        transition applying_to_bonding
            first applying
            then bonding;

        state bonding {
            doc /* Metallurgical bond forming between surfaces */
        }
        
        transition bonding_to_cooling
            first bonding
            then cooling;

        state cooling {
            doc /* Joint cooling to solidify solder */
        }
        
        transition cooling_to_inspection
            first cooling
            then inspection;

        state inspection {
            doc /* Quality check of completed joint */
        }
        
        transition inspection_to_complete
            first inspection
            then complete;
        
        transition inspection_to_rework
            first inspection
            then preheating;

        state complete {
            doc /* Soldering cycle successfully completed */
        }
        
        transition complete_to_idle
            first complete
            accept ResetSignal
            then idle;
    }

    action def PerformSolderingCycle {
        in solder : SolderMaterial;
        in component : ElectricalComponent;
        in board : CircuitBoard;
        in heatingPower : PowerValue;
        out resultJoint : SolderJoint;
        out cycleSuccess : Boolean;

        private attribute currentTemp : ThermodynamicTemperatureValue := 293.15[SI::K];
        private attribute depositedAmount : MassValue := 0.0[SI::kg];
        private attribute bondFormed : Boolean := false;

        first start;
        then merge checkTemperature;

        then action heat : HeatToMeltingPoint {
            in targetTemp = solder.thermalProps.liquidusTemperature;
            in currentTemp = currentTemp;
            in heatingPower = heatingPower;
            out achievedTemp;
            out heatingTime;
        }

        then assign currentTemp := heat.achievedTemp;

        then decide;
            if currentTemp >= solder.thermalProps.meltingPoint then proceedToApply;
            if currentTemp < solder.thermalProps.meltingPoint then checkTemperature;

        action proceedToApply : ApplySolderToJoint {
            in solderMaterial = solder;
            in applicationRate = 0.001[SI::kg];
            in surfaceTemp = currentTemp;
            out depositedMass;
            out coverage;
        }

        then assign depositedAmount := proceedToApply.depositedMass;

        then action formBond : FormMetallurgicalBond {
            in depositedSolder = depositedAmount;
            in componentLead = component;
            in boardPad = board;
            in bondingTemp = currentTemp;
            out joint;
        }

        then assign bondFormed := true;

        then action cool : CoolAndSolidify {
            in coolingRate = 5.0;
            in ambientTemp = 293.15[SI::K];
            in initialTemp = currentTemp;
            out finalTemp;
            out solidificationTime;
        }

        then assign currentTemp := cool.finalTemp;

        then action inspect : InspectJointQuality {
            in joint = formBond.joint;
            in qualityThreshold = 0.85;
            out passed;
            out defectType;
        }

        then decide;
            if inspect.passed == true then finalize;
            if inspect.passed == false then checkTemperature;

        action finalize {
            then assign resultJoint := formBond.joint;
            then assign cycleSuccess := true;
        }

        then done;
    }

    part def SolderingStation {
        attribute operatingVoltage : ISQ::VoltageValue;
        attribute maxPower : PowerValue;
        attribute workingTemperature : ThermodynamicTemperatureValue;

        part heater : HeatingElement {
            attribute :>> maxTemperature = 673.15[SI::K];
            attribute :>> powerRating = 75.0[SI::W];
            attribute :>> heatingRate = 10.0;
        }

        part tempSensor : TemperatureSensor {
            attribute :>> accuracy = 2.0[SI::K];
            attribute :>> responseTime = 0.5[SI::s];
        }

        part controller : ControllerUnit {
            attribute :>> targetTemperature = 573.15[SI::K];
            attribute :>> temperatureTolerance = 5.0[SI::K];
        }

        part solderWire : SolderMaterial {
            attribute :>> composition {
                attribute :>> tinContent = 63.0;
                attribute :>> leadContent = 37.0;
                attribute :>> silverContent = 0.0;
                attribute :>> copperContent = 0.0;
                attribute :>> fluxPercentage = 2.2;
            }
            attribute :>> thermalProps {
                attribute :>> meltingPoint = 456.15[SI::K];
                attribute :>> solidusTemperature = 456.15[SI::K];
                attribute :>> liquidusTemperature = 461.15[SI::K];
                attribute :>> thermalConductivity = 50.0;
            }
            attribute :>> mechanicalProps {
                attribute :>> tensileStrength = 35.0e6[SI::Pa];
                attribute :>> shearStrength = 28.0e6[SI::Pa];
                attribute :>> ductility = 0.45;
            }
            attribute :>> diameter = 0.8[SI::mm];
            attribute :>> length = 5.0[SI::m];
        }

        part targetComponent : ElectricalComponent {
            attribute :>> componentType = "Resistor";
            attribute :>> leadCount = 2;
            attribute :>> leadDiameter = 0.6[SI::mm];
        }

        part pcb : CircuitBoard {
            attribute :>> boardThickness = 1.6[SI::mm];
            attribute :>> copperThickness = 0.035[SI::mm];
            attribute :>> padDiameter = 2.0[SI::mm];
        }

        connection heaterControl : ElectricalInterface
            connect controller.powerCommand to heater.powerInput;

        connection tempFeedback
            connect tempSensor.measuredTemp to controller.currentTemperature;

        connection thermalCoupling : ThermalInterface
            connect heater.thermalOutput to tempSensor.sensing;

        perform action solderingOperation : PerformSolderingCycle {
            in solder = solderWire;
            in component = targetComponent;
            in board = pcb;
            in heatingPower = heater.powerRating;
            out resultJoint;
            out cycleSuccess;
        }
    }

    requirement def ElectricalConductivityRequirement {
        doc /* The solder joint shall provide electrical resistance less than 10 milliohms. */
        
        subject joint : SolderJoint;
        
        require constraint {
            joint.electricalResistance <= 0.010
        }
    }

    requirement def MechanicalStrengthRequirement {
        doc /* The solder joint shall withstand minimum tensile force of 8N without failure. */
        
        subject joint : SolderJoint;
        
        require constraint {
            joint.jointStrength >= 8.0[SI::N]
        }
    }

    requirement def TemperatureControlRequirement {
        doc /* The soldering temperature shall be maintained within ±5K of target during operation. */
        
        subject station : SolderingStation;
        
        require constraint {
            station.controller.currentTemperature >= 
                (station.controller.targetTemperature - station.controller.temperatureTolerance) and
            station.controller.currentTemperature <= 
                (station.controller.targetTemperature + station.controller.temperatureTolerance)
        }
    }

    requirement def JointReliabilityRequirement {
        doc /* The solder joint quality metric shall exceed 0.90 for reliable operation. */
        
        subject joint : SolderJoint;
        
        require constraint {
            joint.jointQuality >= 0.90 and joint.isReliable == true
        }
    }

    requirement <'SOLD-SYS-001'> primarySolderingSystemRequirement {
        doc /* The solder system shall create permanent, electrically conductive, and mechanically 
                robust metallurgical bonds between electronic components and circuit boards through 
                controlled thermal fusion of solder alloy material. */
        
        subject system : SolderingStation;
        
        require electricalReq : ElectricalConductivityRequirement;
        require mechanicalReq : MechanicalStrengthRequirement;
        require tempReq : TemperatureControlRequirement;
        require reliabilityReq : JointReliabilityRequirement;
        
        assume constraint {
            system.solderWire.thermalProps.meltingPoint < 
                system.heater.maxTemperature and
            system.solderWire.thermalProps.liquidusTemperature < 
                system.controller.targetTemperature
        }
    }

    part solderingSystemInstance : SolderingStation {
        attribute :>> operatingVoltage = 24.0[SI::V];
        attribute :>> maxPower = 75.0[SI::W];
        attribute :>> workingTemperature = 573.15[SI::K];
        
        satisfy primarySolderingSystemRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Solder System Model'::*;

    part testSubject : HeatingElement {
        exhibit state sm : SolderingProcessState;
    }

    action orchestrator {
        item testSolderMaterial : SolderMaterial {
            attribute composition : SolderAlloyComposition {
                attribute tinContent = 0.0;
                attribute leadContent = 0.0;
                attribute silverContent = 0.0;
                attribute copperContent = 0.0;
                attribute fluxPercentage = 0.0;
            }
            attribute thermalProps : ThermalProperties {
                attribute meltingPoint : ThermodynamicTemperatureValue;
                attribute solidusTemperature : ThermodynamicTemperatureValue;
                attribute liquidusTemperature : ThermodynamicTemperatureValue;
                attribute thermalConductivity = 0.0;
            }
            attribute mechanicalProps : MechanicalProperties {
                attribute tensileStrength : PressureValue;
                attribute shearStrength : PressureValue;
                attribute ductility = 0.0;
            }
            attribute diameter : LengthValue;
            attribute length : LengthValue;
        }
        attribute testApplicationRate : MassValue;
        attribute testSurfaceTemp : ThermodynamicTemperatureValue;
        action proceedToApplyProbe : ApplySolderToJoint {
            in solderMaterial = testSolderMaterial;
            in applicationRate = testApplicationRate;
            in surfaceTemp = testSurfaceTemp;
        }
        attribute testStartSolderingSignal : StartSolderingSignal;
        attribute testApplySolderSignal : ApplySolderSignal;
        attribute testResetSignal : ResetSignal;
        action triggerStartSolderingSignal send testStartSolderingSignal to testSubject;
        action triggerApplySolderSignal send testApplySolderSignal to testSubject;
        action triggerResetSignal send testResetSignal to testSubject;
        first proceedToApplyProbe;
        then triggerStartSolderingSignal;
        then triggerApplySolderSignal;
        then triggerResetSignal;
    }
}
