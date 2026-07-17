package PantographSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VoltageValue :> ISQ::ElectricPotentialDifferenceValue;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def VelocityValue :> ISQ::SpeedValue;
    attribute def AngleValue :> Real;
    
    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    item def MechanicalForce {
        attribute contactForce : ForceValue;
        attribute upliftForce : ForceValue;
    }
    
    attribute def RaiseCommand;
    attribute def LowerCommand;
    attribute def ContactEstablished;
    attribute def ContactLost;
    attribute def EmergencyLower;
    
    port def ElectricalContactPort {
        out item power : ElectricalPower;
    }
    
    port def MechanicalContactPort {
        in item force : MechanicalForce;
        out attribute height : LengthValue;
    }
    
    port def OverheadWirePort {
        in attribute wireVoltage : VoltageValue;
        in attribute wireHeight : LengthValue;
        out item collectedPower : ElectricalPower;
    }
    
    port def ControlPort {
        in raiseCmd : RaiseCommand;
        in lowerCmd : LowerCommand;
        in emergencyCmd : EmergencyLower;
    }
    
    part def ContactStrip {
        attribute stripMaterial : String;
        attribute wearThickness : LengthValue;
        attribute contactResistance : Real;
        port electricalContact : ElectricalContactPort;
    }
    
    part def CollectorHead {
        attribute headWidth : LengthValue;
        attribute suspensionStiffness : Real;
        part contactStrip : ContactStrip;
        port powerCollection : ElectricalContactPort;
    }
    
    part def UpperArm {
        attribute armLength : LengthValue;
        attribute armMass : ISQ::MassValue;
        attribute pivotAngle : AngleValue;
        port mechanicalJoint : MechanicalContactPort;
    }
    
    part def LowerArm {
        attribute armLength : LengthValue;
        attribute armMass : ISQ::MassValue;
        attribute pivotAngle : AngleValue;
        port mechanicalJoint : MechanicalContactPort;
    }
    
    part def PneumaticActuator {
        attribute operatingPressure : PressureValue;
        attribute cylinderDiameter : LengthValue;
        attribute strokeLength : LengthValue;
        attribute pistonPosition : LengthValue;
        
        action def GenerateUpliftForce {
            in pressure : PressureValue;
            in cylinderArea : Real;
            out upliftForce : ForceValue;
        }
        
        action def ExtendPiston {
            in targetPosition : LengthValue;
            out actualPosition : LengthValue;
        }
        
        action def RetractPiston {
            out finalPosition : LengthValue;
        }
    }
    
    part def SpringAssembly {
        attribute springConstant : Real;
        attribute preloadForce : ForceValue;
        attribute compressionDistance : LengthValue;
        
        action def ProvideContactForce {
            in compression : LengthValue;
            in springK : Real;
            out contactForce : ForceValue;
        }
    }
    
    part def BaseFrame {
        attribute mountingHeight : LengthValue;
        attribute frameWidth : LengthValue;
        port roofMounting;
        port insulatorMounting;
    }
    
    part def Insulator {
        attribute insulationClass : String;
        attribute breakdownVoltage : VoltageValue;
        port electricalIsolation;
    }
    
    part def OverheadContactWire {
        attribute wireVoltage : VoltageValue;
        attribute wireHeight : LengthValue;
        attribute wireTension : ForceValue;
        port wireInterface : OverheadWirePort;
    }
    
    part def VehicleRoof {
        attribute roofHeight : LengthValue;
        port pantographMount;
    }
    
    part def PowerBus {
        attribute busVoltage : VoltageValue;
        attribute busCurrent : CurrentValue;
        port powerInput : ElectricalContactPort;
    }
    
    state def PantographOperationalStates {
        entry; then stowed;
        
        state stowed {
            entry assign pantographAssembly::currentHeight := 0.0[m];
            entry assign pantographAssembly::contactActive := false;
        }
        
        accept raiseCmd : RaiseCommand then raising;
        
        state raising {
            do action activateActuator;
            do action extendArms;
        }
        
        accept contactEstablished : ContactEstablished then operational;
        
        state operational {
            do action maintainContact;
            do action collectPower;
            entry assign pantographAssembly::contactActive := true;
        }
        
        accept lowerCmd : LowerCommand then lowering;
        accept emergencyCmd : EmergencyLower then emergencyLowering;
        accept contactLost : ContactLost then fault;
        
        state lowering {
            do action releaseUpliftForce;
            do action retractArms;
        }
        
        accept stowComplete then stowed;
        
        state emergencyLowering {
            do action rapidRetract;
        }
        
        then stowed;
        
        state fault {
            entry assign pantographAssembly::contactActive := false;
        }
        
        accept raiseCmd : RaiseCommand then raising;
    }
    
    action def RaisePantographToOperatingHeight {
        in targetHeight : LengthValue;
        in operatingPressure : PressureValue;
        out actualHeight : LengthValue;
        out contactForce : ForceValue;
        
        first start;
        then action initializeActuator {
            in pressure = operatingPressure;
        }
        then action extendActuator {
            in targetPos = targetHeight;
            out achievedPos : LengthValue;
        }
        then action deployArms {
            in height = extendActuator.achievedPos;
        }
        then action establishWireContact {
            out force : ForceValue;
        }
        then assign actualHeight := extendActuator.achievedPos;
        then assign contactForce := establishWireContact.force;
        then done;
    }
    
    action def MaintainElectricalContact {
        in wireHeight : LengthValue;
        in wireVoltage : VoltageValue;
        in nominalForce : ForceValue;
        out collectedPower : ElectricalPower;
        
        loop {
            action monitorWirePosition {
                in currentWireHeight : LengthValue;
                in pantographHeight : LengthValue;
                out heightDeviation : LengthValue;
            }
            then action monitorContactForce {
                in measuredForce : ForceValue;
                in targetForce : ForceValue;
                out forceDeviation : ForceValue;
            }
            then decide;
                if monitorWirePosition.heightDeviation > 0.08[m] then adjustHeight;
                if monitorContactForce.forceDeviation > 15.0[N] then adjustForce;
                if monitorWirePosition.heightDeviation <= 0.08[m] and 
                   monitorContactForce.forceDeviation <= 15.0[N] then collectPower;
            
            action adjustHeight {
                in deviation : LengthValue;
                out newHeight : LengthValue;
            }
            then collectPower;
            
            action adjustForce {
                in deviation : ForceValue;
                out newForce : ForceValue;
            }
            then collectPower;
            
            action collectPower {
                in voltage = wireVoltage;
                in current : CurrentValue;
                out power : ElectricalPower;
            }
            then assign collectedPower := collectPower.power;
        }
    }
    
    action def LowerPantographToStowedPosition {
        out finalHeight : LengthValue;
        
        first start;
        then action releaseContactForce;
        then action deactivateActuator;
        then action retractArms {
            out retractedHeight : LengthValue;
        }
        then action secureInStowedPosition;
        then assign finalHeight := retractArms.retractedHeight;
        then done;
    }
    
    part def PantographAssembly {
        attribute operatingVoltage : VoltageValue;
        attribute nominalContactForce : ForceValue;
        attribute maxContactForce : ForceValue;
        attribute operatingHeight : LengthValue;
        attribute stowedHeight : LengthValue;
        attribute maxCurrent : CurrentValue;
        
        attribute currentHeight : LengthValue;
        attribute contactActive : Boolean;
        
        port wireContact : OverheadWirePort;
        port vehiclePowerOutput : ElectricalContactPort;
        port controlInterface : ControlPort;
        
        part collectorHead : CollectorHead;
        part upperArm : UpperArm;
        part lowerArm : LowerArm;
        part actuator : PneumaticActuator;
        part springAssembly : SpringAssembly;
        part baseFrame : BaseFrame;
        part insulator : Insulator;
        
        state lifecycle : PantographOperationalStates;
    }
    
    part pantographAssembly : PantographAssembly {
        :>> operatingVoltage = 25000.0[V];
        :>> nominalContactForce = 70.0[N];
        :>> maxContactForce = 120.0[N];
        :>> operatingHeight = 5.5[m];
        :>> stowedHeight = 0.4[m];
        :>> maxCurrent = 800.0[A];
        
        part redefines collectorHead {
            :>> headWidth = 1.45[m];
        }
        
        part redefines upperArm {
            :>> armLength = 1.95[m];
            :>> armMass = 12.5[kg];
        }
        
        part redefines lowerArm {
            :>> armLength = 1.75[m];
            :>> armMass = 15.0[kg];
        }
        
        part redefines actuator {
            :>> operatingPressure = 6.0[bar];
            :>> cylinderDiameter = 0.08[m];
            :>> strokeLength = 1.2[m];
        }
        
        part redefines springAssembly {
            :>> springConstant = 850.0;
            :>> preloadForce = 50.0[N];
        }
        
        part redefines baseFrame {
            :>> mountingHeight = 0.35[m];
            :>> frameWidth = 1.2[m];
        }
        
        part redefines insulator {
            :>> insulationClass = "Class C";
            :>> breakdownVoltage = 75000.0[V];
        }
        
        connection upperToLowerArm connect upperArm.mechanicalJoint to lowerArm.mechanicalJoint;
        connection lowerArmToBase connect lowerArm.mechanicalJoint to baseFrame.roofMounting;
        connection upperArmToHead connect upperArm.mechanicalJoint to collectorHead.powerCollection;
        connection baseToInsulator connect baseFrame.insulatorMounting to insulator.electricalIsolation;
        
        perform action raiseToOperatingHeight : RaisePantographToOperatingHeight {
            in targetHeight = operatingHeight;
            in operatingPressure = actuator.operatingPressure;
            out actualHeight;
            out contactForce;
        }
        
        perform action maintainContact : MaintainElectricalContact {
            in wireHeight = wireContact.wireHeight;
            in wireVoltage = wireContact.wireVoltage;
            in nominalForce = nominalContactForce;
            out collectedPower;
        }
        
        binding collectedPower = wireContact.collectedPower;
        
        perform action lowerToStowed : LowerPantographToStowedPosition {
            out finalHeight;
        }
    }
    
    part def ElectricRailVehiclePowerCollection {
        part pantograph : PantographAssembly;
        part vehicleRoof : VehicleRoof;
        part overheadWire : OverheadContactWire;
        part powerBus : PowerBus;
    }
    
    part system : ElectricRailVehiclePowerCollection {
        part redefines pantograph : PantographAssembly;
        part redefines vehicleRoof {
            :>> roofHeight = 3.8[m];
        }
        part redefines overheadWire {
            :>> wireVoltage = 25000.0[V];
            :>> wireHeight = 5.5[m];
            :>> wireTension = 15000.0[N];
        }
        part redefines powerBus {
            :>> busVoltage = 25000.0[V];
        }
        
        connection pantographToRoof connect pantograph.baseFrame.roofMounting to vehicleRoof.pantographMount;
        connection pantographToWire connect pantograph.wireContact to overheadWire.wireInterface;
        connection pantographToBus connect pantograph.vehiclePowerOutput to powerBus.powerInput;
    }
    
    requirement def SystemPrimaryFunction {
        doc /* The pantograph system shall collect electrical power from an overhead contact wire 
               and deliver it to the vehicle's electrical system to enable traction and auxiliary functions. */
    }
    
    requirement def ContactForceRequirement {
        doc /* The pantograph shall maintain adequate contact force with the overhead wire. */
    }
    
    requirement def VoltageCollectionRequirement {
        doc /* The pantograph shall collect power at the specified system voltage. */
    }
    
    requirement def HeightAdaptationRequirement {
        doc /* The pantograph shall adapt to variations in overhead wire height. */
    }
    
    requirement def SafetyRequirement {
        doc /* The pantograph shall provide electrical isolation and safe operation. */
    }
    
    requirement <'PAN-REQ-001'> primaryFunction : SystemPrimaryFunction {
        doc /* The pantograph system provides the critical electrical interface between a railway vehicle 
               and the overhead power distribution network. Its primary function is to establish and maintain 
               continuous electrical contact with the overhead contact wire, collecting high-voltage electrical 
               power and transferring it to the vehicle's power bus. This enables the vehicle's traction motors 
               and auxiliary systems to operate, allowing the vehicle to move and function. The system must 
               reliably maintain contact across varying wire heights, vehicle speeds, and environmental conditions 
               while ensuring electrical safety through proper insulation. */
    }
    
    requirement <'PAN-REQ-002'> contactForceSpec : ContactForceRequirement {
        doc /* The pantograph shall maintain a contact force between 70 N and 120 N against the overhead wire 
               to ensure reliable electrical contact without excessive wear. */
        
        require constraint forceRange {
            pantographAssembly.nominalContactForce >= 70.0[N] and
            pantographAssembly.maxContactForce <= 120.0[N]
        }
    }
    
    requirement <'PAN-REQ-003'> voltageCollection : VoltageCollectionRequirement {
        doc /* The pantograph shall collect power at the nominal system voltage of 25 kV AC. */
        
        require constraint voltageSpec {
            pantographAssembly.operatingVoltage == 25000.0[V]
        }
    }
    
    requirement <'PAN-REQ-004'> heightAdaptation : HeightAdaptationRequirement {
        doc /* The pantograph shall automatically adjust to overhead wire height variations 
               within ±150 mm of nominal height. */
        
        require constraint heightRange {
            abs(pantographAssembly.operatingHeight - system.overheadWire.wireHeight) <= 0.15[m]
        }
    }
    
    requirement <'PAN-REQ-005'> electricalSafety : SafetyRequirement {
        doc /* The pantograph shall provide electrical isolation with minimum breakdown voltage of 75 kV. */
        
        require constraint insulationSpec {
            pantographAssembly.insulator.breakdownVoltage >= 75000.0[V]
        }
    }
    
    requirement systemMission {
        doc /* The electric rail vehicle power collection system shall enable continuous vehicle operation 
               by reliably collecting electrical power from the overhead contact wire infrastructure. */
        
        assume constraint overheadWirePresent {
            system.overheadWire.wireVoltage > 0.0[V]
        }
        
        require primaryFunction;
        require contactForceSpec;
        require voltageCollection;
        require heightAdaptation;
        require electricalSafety;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import PantographSystem::*;

    part testSubject : ContactStrip {
        exhibit state sm : PantographOperationalStates;
    }

    action orchestrator {
        attribute testPressure : PressureValue;
        action actionProbe : GenerateUpliftForce {
            in pressure = testPressure;
            in cylinderArea = 0.0;
        }
        first actionProbe;
    }
}
