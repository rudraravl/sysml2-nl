package PantographSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def LengthValue :> ISQ::length {
        unit = SI::metre;
    }

    attribute def AngleValue :> ISQ::planeAngle {
        unit = SI::radian;
    }

    attribute def ForceValue :> ISQ::force {
        unit = SI::newton;
    }

    attribute def VelocityValue :> ISQ::speed {
        unit = SI::metrePerSecond;
    }

    attribute def VoltageValue :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def CurrentValue :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def PowerValue :> ISQ::power {
        unit = SI::watt;
    }

    attribute def MassValue :> ISQ::mass {
        unit = SI::kilogram;
    }

    attribute def StiffnessValue {
        :>> unit = SI::newtonPerMetre;
    }

    item def ElectricPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute power : PowerValue;
    }

    item def ContactForce {
        attribute normalForce : ForceValue;
        attribute lateralForce : ForceValue;
    }

    item def RaiseCommand {
        attribute requestedHeight : LengthValue;
        attribute rateLimit : VelocityValue;
    }

    item def LowerCommand {
        attribute targetHeight : LengthValue;
        attribute rateLimit : VelocityValue;
    }

    item def PantographStatus {
        attribute currentHeight : LengthValue;
        attribute contactEstablished : Boolean;
        attribute contactForce : ForceValue;
        attribute lockedDown : Boolean;
        attribute faultActive : Boolean;
    }

    port def MechanicalMountPort {
        out loadToVehicle : ForceValue;
        in reactionFromVehicle : ForceValue;
    }

    port def OverheadContactPort {
        in lineVoltage : VoltageValue;
        out contactForce : ContactForce;
        out collectedPower : ElectricPower;
    }

    port def ElectricalOutputPort {
        out tractionPower : ElectricPower;
    }

    port def PneumaticSupplyPort {
        in supplyPressure : PressureValue;
    }

    port def ControlPort {
        in raise : RaiseCommand;
        in lower : LowerCommand;
        in emergencyLower : Boolean;
        out status : PantographStatus;
    }

    port def SensorPort {
        out measuredHeight : LengthValue;
        out measuredContactForce : ForceValue;
        out measuredVoltage : VoltageValue;
        out faultDetected : Boolean;
    }

    part def BaseFrame {
        attribute mass : MassValue = 45 [SI::kilogram];
        attribute mountingHoleSpacing : LengthValue = 1.2 [SI::metre];

        port mount : MechanicalMountPort;
    }

    part def LowerArm {
        attribute length : LengthValue = 1.05 [SI::metre];
        attribute mass : MassValue = 18 [SI::kilogram];
        attribute angle : AngleValue;

        port lowerPivot : MechanicalMountPort;
        port upperJoint : MechanicalMountPort;
    }

    part def UpperArm {
        attribute length : LengthValue = 1.00 [SI::metre];
        attribute mass : MassValue = 14 [SI::kilogram];
        attribute angle : AngleValue;

        port lowerJoint : MechanicalMountPort;
        port headJoint : MechanicalMountPort;
    }

    part def Linkage {
        attribute effectiveReach : LengthValue;
        attribute deployedHeight : LengthValue;
        attribute maximumHeight : LengthValue = 2.1 [SI::metre];
        attribute minimumHeight : LengthValue = 0.25 [SI::metre];

        part lowerArm : LowerArm;
        part upperArm : UpperArm;

        port baseInterface : MechanicalMountPort;
        port headInterface : MechanicalMountPort;

        connect baseInterface to lowerArm.lowerPivot;
        connect lowerArm.upperJoint to upperArm.lowerJoint;
        connect upperArm.headJoint to headInterface;
    }

    part def ContactStrip {
        attribute length : LengthValue = 1.6 [SI::metre];
        attribute wearLimit : LengthValue = 0.006 [SI::metre];
        attribute remainingWearDepth : LengthValue = 0.018 [SI::metre];
        attribute allowableCurrent : CurrentValue = 1200 [SI::ampere];

        port overheadInterface : OverheadContactPort;
    }

    part def CollectorHead {
        attribute headMass : MassValue = 22 [SI::kilogram];
        attribute workingWidth : LengthValue = 1.95 [SI::metre];
        attribute verticalCompliance : StiffnessValue = 18000;
        attribute nominalContactForce : ForceValue = 90 [SI::newton];

        part primaryStrip : ContactStrip;
        part secondaryStrip : ContactStrip;

        port linkageInterface : MechanicalMountPort;
        port overhead : OverheadContactPort;

        connect overhead to primaryStrip.overheadInterface;
        connect overhead to secondaryStrip.overheadInterface;
    }

    part def RaisingActuator {
        attribute stroke : LengthValue = 0.42 [SI::metre];
        attribute extensionRate : VelocityValue = 0.18 [SI::metrePerSecond];
        attribute maximumLiftForce : ForceValue = 1800 [SI::newton];
        attribute commandedExtension : LengthValue;

        port pneumaticSupply : PneumaticSupplyPort;
        port baseAttachment : MechanicalMountPort;
        port linkageAttachment : MechanicalMountPort;
    }

    part def DownforceSpring {
        attribute preloadForce : ForceValue = 85 [SI::newton];
        attribute springRate : StiffnessValue = 2200;
        attribute deflection : LengthValue;

        port fixedEnd : MechanicalMountPort;
        port movingEnd : MechanicalMountPort;
    }

    part def LockDownLatch {
        attribute locked : Boolean;
        attribute releaseForce : ForceValue = 250 [SI::newton];

        port latchBase : MechanicalMountPort;
        port latchHook : MechanicalMountPort;
    }

    part def ElectricalBus {
        attribute insulationRating : VoltageValue = 30000 [SI::volt];
        attribute continuousCurrentRating : CurrentValue = 1000 [SI::ampere];

        port collectorInput : OverheadContactPort;
        port vehicleOutput : ElectricalOutputPort;
    }

    part def SensorSuite {
        attribute heightAccuracy : LengthValue = 0.01 [SI::metre];
        attribute forceAccuracy : ForceValue = 5 [SI::newton];
        attribute voltageMeasurementRange : VoltageValue = 30000 [SI::volt];

        port sensing : SensorPort;
    }

    action def RaisePantograph {
        in command : RaiseCommand;
        in currentHeight : LengthValue;
        out targetHeight : LengthValue;
        out actuatorExtension : LengthValue;

        first start;
        then validateCommand;
        then releaseLatch;
        then extendActuator;
        then regulateContactForce;
        then reportRaised;
    }

    action def LowerPantograph {
        in command : LowerCommand;
        in currentHeight : LengthValue;
        out targetHeight : LengthValue;
        out actuatorExtension : LengthValue;

        first start;
        then reduceContactForce;
        then retractActuator;
        then engageLatch;
        then reportLowered;
    }

    action def CollectElectricPower {
        in lineVoltage : VoltageValue;
        in requestedCurrent : CurrentValue;
        in contactForce : ForceValue;
        out deliveredPower : ElectricPower;

        first detectContact;
        then verifyForceWithinRange;
        then conductCurrentThroughStrips;
        then transferPowerToVehicleBus;
    }

    action def EmergencyDrop {
        in faultActive : Boolean;
        out lowered : Boolean;

        first detectEmergency;
        then ventActuatorPressure;
        then forceRetractLinkage;
        then confirmNoOverheadContact;
    }

    state def PantographOperatingState {
        entry action initializeStatus;

        state stowed;
        state raising;
        state inContact;
        state collectingPower;
        state lowering;
        state lockedDown;
        state faulted;

        initial then stowed;

        transition stowed_to_raising
            first stowed
            accept RaiseCommand
            then raising;

        transition raising_to_contact
            first raising
            accept ContactForce
            if measuredContactForce >= 70 [SI::newton] and measuredContactForce <= 120 [SI::newton]
            then inContact;

        transition contact_to_collecting
            first inContact
            if measuredVoltage > 500 [SI::volt]
            then collectingPower;

        transition collecting_to_lowering
            first collectingPower
            accept LowerCommand
            then lowering;

        transition contact_to_lowering
            first inContact
            accept LowerCommand
            then lowering;

        transition lowering_to_locked
            first lowering
            if measuredHeight <= 0.30 [SI::metre]
            then lockedDown;

        transition locked_to_stowed
            first lockedDown
            then stowed;

        transition any_to_faulted
            first stowed
            accept Boolean
            if faultDetected
            then faulted;

        transition collecting_to_faulted
            first collectingPower
            if measuredContactForce < 40 [SI::newton] or measuredContactForce > 160 [SI::newton]
            then faulted;

        transition faulted_to_lowering
            first faulted
            accept Boolean
            if emergencyLower
            then lowering;
    }

    part def Pantograph {
        attribute minimumOperatingHeight : LengthValue = 0.45 [SI::metre];
        attribute maximumOperatingHeight : LengthValue = 2.05 [SI::metre];
        attribute nominalContactForce : ForceValue = 90 [SI::newton];
        attribute maximumCollectionCurrent : CurrentValue = 1000 [SI::ampere];
        attribute maximumLineVoltage : VoltageValue = 25000 [SI::volt];
        attribute deployed : Boolean;
        attribute contactEstablished : Boolean;

        part baseFrame : BaseFrame;
        part linkage : Linkage;
        part collectorHead : CollectorHead;
        part actuator : RaisingActuator;
        part downforceSpring : DownforceSpring;
        part latch : LockDownLatch;
        part electricalBus : ElectricalBus;
        part sensors : SensorSuite;

        port vehicleMount : MechanicalMountPort;
        port overheadContact : OverheadContactPort;
        port vehiclePower : ElectricalOutputPort;
        port pneumaticInput : PneumaticSupplyPort;
        port control : ControlPort;
        port sensorOutput : SensorPort;

        perform raiseBehavior : RaisePantograph;
        perform lowerBehavior : LowerPantograph;
        perform powerCollection : CollectElectricPower;
        perform emergencyBehavior : EmergencyDrop;

        exhibit stateMachine : PantographOperatingState;

        connect vehicleMount to baseFrame.mount;
        connect baseFrame.mount to linkage.baseInterface;
        connect linkage.headInterface to collectorHead.linkageInterface;
        connect collectorHead.overhead to overheadContact;
        connect overheadContact to electricalBus.collectorInput;
        connect electricalBus.vehicleOutput to vehiclePower;
        connect pneumaticInput to actuator.pneumaticSupply;
        connect actuator.baseAttachment to baseFrame.mount;
        connect actuator.linkageAttachment to linkage.baseInterface;
        connect downforceSpring.fixedEnd to baseFrame.mount;
        connect downforceSpring.movingEnd to linkage.headInterface;
        connect latch.latchBase to baseFrame.mount;
        connect latch.latchHook to linkage.baseInterface;
        connect sensors.sensing to sensorOutput;
    }

    part def VehicleRoofInterface {
        attribute roofMountCapacity : ForceValue = 5000 [SI::newton];
        attribute availablePneumaticPressure : PressureValue = 700000 [SI::pascal];

        port mountPoint : MechanicalMountPort;
        port airSupply : PneumaticSupplyPort;
        port powerInput : ElectricalOutputPort;
        port controlInterface : ControlPort;
    }

    part def OverheadContactLine {
        attribute nominalVoltage : VoltageValue = 25000 [SI::volt];
        attribute allowableCurrent : CurrentValue = 1200 [SI::ampere];
        attribute contactWireHeight : LengthValue = 5.3 [SI::metre];
        attribute staggerAmplitude : LengthValue = 0.30 [SI::metre];

        port contactWire : OverheadContactPort;
    }

    part def PantographBasedCurrentCollectionSystem {
        attribute primaryFunction : String = "Maintain controlled sliding contact with an overhead conductor and transfer electrical power from the line to the vehicle while accommodating relative motion.";
        attribute operatingSpeed : VelocityValue = 55 [SI::metrePerSecond];
        attribute requiredContactForce : ForceValue = 90 [SI::newton];
        attribute deliveredPowerCapability : PowerValue = 25000000 [SI::watt];

        part pantograph : Pantograph;
        part vehicleInterface : VehicleRoofInterface;
        part overheadLine : OverheadContactLine;

        port vehicleControl : ControlPort;
        port tractionPowerOut : ElectricalOutputPort;

        connect vehicleInterface.mountPoint to pantograph.vehicleMount;
        connect vehicleInterface.airSupply to pantograph.pneumaticInput;
        connect vehicleInterface.controlInterface to pantograph.control;
        connect vehicleControl to pantograph.control;
        connect overheadLine.contactWire to pantograph.overheadContact;
        connect pantograph.vehiclePower to vehicleInterface.powerInput;
        connect pantograph.vehiclePower to tractionPowerOut;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The pantograph system shall raise from a stowed position, establish controlled mechanical contact with an overhead contact wire, and transfer electrical power to the vehicle. */
        subject pantographSystem : PantographBasedCurrentCollectionSystem;

        require constraint {
            pantographSystem.pantograph.contactEstablished == true implies
            pantographSystem.pantograph.nominalContactForce >= 70 [SI::newton] and
            pantographSystem.pantograph.nominalContactForce <= 120 [SI::newton]
        }
    }

    requirement def HeightEnvelopeRequirement {
        doc /* The pantograph shall operate within its mechanical height envelope while maintaining contact with the overhead line. */
        subject pantograph : Pantograph;

        require constraint {
            pantograph.minimumOperatingHeight >= 0.45 [SI::metre] and
            pantograph.maximumOperatingHeight <= 2.10 [SI::metre]
        }
    }

    requirement def PowerTransferRequirement {
        doc /* The pantograph shall transfer continuous electrical power from the overhead contact line to the vehicle electrical bus at the specified voltage and current limits. */
        subject pantograph : Pantograph;

        require constraint {
            pantograph.maximumLineVoltage >= 25000 [SI::volt] and
            pantograph.maximumCollectionCurrent >= 1000 [SI::ampere]
        }
    }

    requirement def FailSafeLoweringRequirement {
        doc /* The pantograph shall lower away from the overhead contact wire when an emergency lower command or contact-force fault is detected. */
        subject pantograph : Pantograph;

        require constraint {
            pantograph.deployed == false implies pantograph.contactEstablished == false
        }
    }

    requirement def ContactStripWearRequirement {
        doc /* Each contact strip shall retain sufficient wear depth for safe current collection. */
        subject strip : ContactStrip;

        require constraint {
            strip.remainingWearDepth >= strip.wearLimit
        }
    }

    satisfy PrimaryFunctionRequirement by PantographBasedCurrentCollectionSystem;
    satisfy HeightEnvelopeRequirement by Pantograph;
    satisfy PowerTransferRequirement by Pantograph;
    satisfy FailSafeLoweringRequirement by Pantograph;
    satisfy ContactStripWearRequirement by ContactStrip;

}