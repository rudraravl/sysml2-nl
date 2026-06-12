package ElectroscopeSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ElectricCharge :> ISQ::electricCharge {
        unit = SI::coulomb;
    }

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Capacitance :> ISQ::capacitance {
        unit = SI::farad;
    }

    attribute def Force :> ISQ::force {
        unit = SI::newton;
    }

    attribute def Angle :> ISQ::planeAngle {
        unit = SI::degree;
    }

    attribute def Length :> ISQ::length {
        unit = SI::meter;
    }

    attribute def Mass :> ISQ::mass {
        unit = SI::kilogram;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::second;
    }

    enum def ChargePolarity {
        enum neutral;
        enum positive;
        enum negative;
        enum unknown;
    }

    enum def IndicationMode {
        enum noDeflection;
        enum weakDeflection;
        enum moderateDeflection;
        enum strongDeflection;
        enum saturatedDeflection;
    }

    enum def OperatingState {
        enum uncharged;
        enum chargingByContact;
        enum chargingByInduction;
        enum charged;
        enum discharging;
        enum observing;
        enum faulted;
    }

    item def ElectricChargeCarrier {
        attribute charge : ElectricCharge;
        attribute polarity : ChargePolarity;
        attribute potential : ElectricPotential;
    }

    item def ExternalChargedObject {
        attribute netCharge : ElectricCharge;
        attribute polarity : ChargePolarity;
        attribute surfacePotential : ElectricPotential;
        attribute distanceFromTerminal : Length;
    }

    item def ElectrostaticInfluence {
        attribute inducedChargeSeparation : ElectricCharge;
        attribute fieldPotential : ElectricPotential;
        attribute sourcePolarity : ChargePolarity;
    }

    item def MechanicalDeflectionSignal {
        attribute leafAngle : Angle;
        attribute indication : IndicationMode;
        attribute responseTime : TimeDuration;
    }

    item def GroundReference {
        attribute potential : ElectricPotential = 0 [SI::volt];
    }

    port def ChargePort {
        in item incomingCharge : ElectricChargeCarrier;
        out item outgoingCharge : ElectricChargeCarrier;
    }

    port def FieldSensePort {
        in item externalInfluence : ElectrostaticInfluence;
        in item nearbyObject : ExternalChargedObject;
    }

    port def GroundPort {
        in item ground : GroundReference;
        out item dischargedCarrier : ElectricChargeCarrier;
    }

    port def VisualIndicationPort {
        out item deflectionSignal : MechanicalDeflectionSignal;
    }

    port def MechanicalSupportPort {
        in attribute supportReaction : Force;
        out attribute suspendedMassLoad : Force;
    }

    requirement def DetectElectrostaticChargeRequirement {
        doc /* The electroscope shall detect the presence of net electric charge on or near its sensing terminal by producing a visible mechanical deflection of conductive leaves. */

        subject electroscope : SimpleLeafElectroscope;

        require constraint {
            electroscope.visualOutput.deflectionSignal.leafAngle >= 0 [SI::degree]
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The primary high-level function of the electroscope is to convert electrostatic charge or electrostatic influence into a visible leaf separation that indicates the presence and relative magnitude of charge. */

        subject electroscope : SimpleLeafElectroscope;

        require constraint {
            electroscope.detectedChargeMagnitude >= electroscope.minimumDetectableCharge implies
            electroscope.visualOutput.deflectionSignal.indication != IndicationMode::noDeflection
        }
    }

    requirement def IsolationRequirement {
        doc /* The insulating stopper and enclosure shall reduce unwanted leakage so that the indicated deflection remains observable for a finite hold time after charging. */

        subject electroscope : SimpleLeafElectroscope;

        require constraint {
            electroscope.chargeRetentionTime >= 30 [SI::second]
        }
    }

    requirement def DischargeRequirement {
        doc /* When connected to ground, the electroscope shall dissipate accumulated charge and return the leaves to the no-deflection condition. */

        subject electroscope : SimpleLeafElectroscope;

        require constraint {
            electroscope.currentState == OperatingState::discharging implies
            electroscope.visualOutput.deflectionSignal.leafAngle <= 1 [SI::degree]
        }
    }

    action def ReceiveChargeByContact {
        in item transferredCarrier : ElectricChargeCarrier;
        out attribute accumulatedCharge : ElectricCharge;
        out attribute terminalPotential : ElectricPotential;

        action acceptCharge;
        action distributeCharge;
        action updatePotential;

        flow transferredCarrier from acceptCharge to distributeCharge;
        flow accumulatedCharge from distributeCharge to updatePotential;
    }

    action def SenseChargeByInduction {
        in item chargedObject : ExternalChargedObject;
        out item influence : ElectrostaticInfluence;
        out attribute separatedCharge : ElectricCharge;

        action detectElectricField;
        action polarizeConductor;
        action computeSeparation;

        flow chargedObject from detectElectricField to polarizeConductor;
        flow influence from polarizeConductor to computeSeparation;
    }

    action def ConvertChargeToLeafDeflection {
        in attribute leafCharge : ElectricCharge;
        in attribute leafMass : Mass;
        in attribute leafLength : Length;
        out item signal : MechanicalDeflectionSignal;

        action calculateRepulsiveForce;
        action calculateEquilibriumAngle;
        action classifyIndication;

        flow leafCharge from calculateRepulsiveForce to calculateEquilibriumAngle;
        flow signal from calculateEquilibriumAngle to classifyIndication;
    }

    action def DischargeToGround {
        in item ground : GroundReference;
        in attribute storedCharge : ElectricCharge;
        out attribute remainingCharge : ElectricCharge;
        out item dischargedCarrier : ElectricChargeCarrier;

        action establishGroundPath;
        action neutralizeTerminal;
        action collapseLeafDeflection;

        flow ground from establishGroundPath to neutralizeTerminal;
        flow remainingCharge from neutralizeTerminal to collapseLeafDeflection;
    }

    state def ElectroscopeOperation {
        entry action initialize {
            out attribute initialCharge : ElectricCharge = 0 [SI::coulomb];
        }

        state uncharged;
        state chargingByContact;
        state chargingByInduction;
        state charged;
        state observing;
        state discharging;
        state faulted;

        transition first uncharged;

        transition contactCharging
            first uncharged
            then chargingByContact
            accept item carrier : ElectricChargeCarrier
            if carrier.charge != 0 [SI::coulomb];

        transition inductionCharging
            first uncharged
            then chargingByInduction
            accept item object : ExternalChargedObject
            if object.netCharge != 0 [SI::coulomb];

        transition contactChargeEstablished
            first chargingByContact
            then charged;

        transition inductionChargeEstablished
            first chargingByInduction
            then observing;

        transition beginObservation
            first charged
            then observing;

        transition groundDischarge
            first observing
            then discharging
            accept item ground : GroundReference;

        transition resetAfterDischarge
            first discharging
            then uncharged;

        transition leakageFault
            first charged
            then faulted
            if true;

        transition recoverFromFault
            first faulted
            then uncharged;
    }

    part def ConductiveTerminal {
        attribute radius : Length = 0.012 [SI::meter];
        attribute terminalCharge : ElectricCharge = 0 [SI::coulomb];
        attribute terminalPotential : ElectricPotential = 0 [SI::volt];
        attribute capacitanceToEnvironment : Capacitance = 3.0e-12 [SI::farad];

        port chargeInterface : ChargePort;
        port fieldInterface : FieldSensePort;
        port supportInterface : MechanicalSupportPort;
    }

    part def ConductiveStem {
        attribute length : Length = 0.115 [SI::meter];
        attribute diameter : Length = 0.0015 [SI::meter];
        attribute stemCharge : ElectricCharge = 0 [SI::coulomb];
        attribute stemPotential : ElectricPotential = 0 [SI::volt];

        port upperChargeInterface : ChargePort;
        port lowerChargeInterface : ChargePort;
        port supportInterface : MechanicalSupportPort;
    }

    part def ConductiveLeaf {
        attribute length : Length = 0.045 [SI::meter];
        attribute width : Length = 0.006 [SI::meter];
        attribute thickness : Length = 2.0e-6 [SI::meter];
        attribute mass : Mass = 2.5e-5 [SI::kilogram];
        attribute leafCharge : ElectricCharge = 0 [SI::coulomb];
        attribute leafPotential : ElectricPotential = 0 [SI::volt];
        attribute deflectionAngle : Angle = 0 [SI::degree];

        port chargeInterface : ChargePort;
        port hingeSupport : MechanicalSupportPort;
    }

    part def LeafPair {
        part leftLeaf : ConductiveLeaf {
            attribute deflectionAngle : Angle = 0 [SI::degree];
        }

        part rightLeaf : ConductiveLeaf {
            attribute deflectionAngle : Angle = 0 [SI::degree];
        }

        attribute averageDeflection : Angle = 0 [SI::degree];
        attribute chargeOnEachLeaf : ElectricCharge = 0 [SI::coulomb];
        attribute electrostaticRepulsiveForce : Force = 0 [SI::newton];

        port commonChargeInterface : ChargePort;
        port indicationOutput : VisualIndicationPort;
        port suspensionSupport : MechanicalSupportPort;

        perform action convertChargeToDeflection : ConvertChargeToLeafDeflection {
            in leafCharge = chargeOnEachLeaf;
            in leafMass = leftLeaf.mass;
            in leafLength = leftLeaf.length;
            out signal = indicationOutput.deflectionSignal;
        }

        connect commonChargeInterface to leftLeaf.chargeInterface;
        connect commonChargeInterface to rightLeaf.chargeInterface;
        connect suspensionSupport to leftLeaf.hingeSupport;
        connect suspensionSupport to rightLeaf.hingeSupport;
    }

    part def InsulatingStopper {
        attribute thickness : Length = 0.018 [SI::meter];
        attribute leakageResistanceEquivalent : Real = 1.0e14;
        attribute maximumSupportedLoad : Force = 0.15 [SI::newton];

        port upperSupport : MechanicalSupportPort;
        port lowerSupport : MechanicalSupportPort;
    }

    part def GlassEnclosure {
        attribute height : Length = 0.170 [SI::meter];
        attribute diameter : Length = 0.075 [SI::meter];
        attribute wallThickness : Length = 0.002 [SI::meter];
        attribute internalHumidityFraction : Real = 0.35;

        port enclosureSupport : MechanicalSupportPort;
    }

    part def GroundingKnob {
        attribute contactResistanceEquivalent : Real = 1.0e3;

        port groundInterface : GroundPort;
        port chargeInterface : ChargePort;
    }

    part def ScalePlate {
        attribute minimumVisibleAngle : Angle = 1 [SI::degree];
        attribute maximumMarkedAngle : Angle = 45 [SI::degree];

        port visualInput : VisualIndicationPort;
    }

    part def SimpleLeafElectroscope {
        doc /* A simple leaf electroscope is an electrostatic indicating instrument. A charged object touching or approaching the terminal causes charge distribution through the conductor. Like charge on the two leaves produces mutual repulsion, separating the leaves. The visible separation indicates the presence and approximate relative magnitude of electric charge. */

        attribute totalStoredCharge : ElectricCharge = 0 [SI::coulomb];
        attribute detectedChargeMagnitude : ElectricCharge = 0 [SI::coulomb];
        attribute minimumDetectableCharge : ElectricCharge = 1.0e-10 [SI::coulomb];
        attribute maximumIndicatingCharge : ElectricCharge = 5.0e-8 [SI::coulomb];
        attribute terminalPotential : ElectricPotential = 0 [SI::volt];
        attribute chargeRetentionTime : TimeDuration = 60 [SI::second];
        attribute currentState : OperatingState = OperatingState::uncharged;

        part terminal : ConductiveTerminal;
        part stem : ConductiveStem;
        part leaves : LeafPair;
        part stopper : InsulatingStopper;
        part enclosure : GlassEnclosure;
        part groundingKnob : GroundingKnob;
        part scale : ScalePlate;

        port sensingTerminal : ChargePort;
        port fieldSensor : FieldSensePort;
        port groundConnection : GroundPort;
        port visualOutput : VisualIndicationPort;

        connect sensingTerminal to terminal.chargeInterface;
        connect fieldSensor to terminal.fieldInterface;
        connect terminal.chargeInterface to stem.upperChargeInterface;
        connect stem.lowerChargeInterface to leaves.commonChargeInterface;
        connect leaves.indicationOutput to visualOutput;
        connect groundConnection to groundingKnob.groundInterface;
        connect groundingKnob.chargeInterface to stem.upperChargeInterface;
        connect leaves.indicationOutput to scale.visualInput;

        connect terminal.supportInterface to stopper.upperSupport;
        connect stopper.lowerSupport to stem.supportInterface;
        connect stem.supportInterface to leaves.suspensionSupport;
        connect enclosure.enclosureSupport to stopper.lowerSupport;

        perform action contactCharging : ReceiveChargeByContact {
            in transferredCarrier = sensingTerminal.incomingCharge;
            out accumulatedCharge = totalStoredCharge;
            out terminalPotential = terminalPotential;
        }

        perform action inductionSensing : SenseChargeByInduction {
            in chargedObject = fieldSensor.nearbyObject;
            out influence = fieldSensor.externalInfluence;
            out separatedCharge = detectedChargeMagnitude;
        }

        perform action leafIndication : ConvertChargeToLeafDeflection {
            in leafCharge = leaves.chargeOnEachLeaf;
            in leafMass = leaves.leftLeaf.mass;
            in leafLength = leaves.leftLeaf.length;
            out signal = visualOutput.deflectionSignal;
        }

        perform action grounding : DischargeToGround {
            in ground = groundConnection.ground;
            in storedCharge = totalStoredCharge;
            out remainingCharge = totalStoredCharge;
            out dischargedCarrier = groundConnection.dischargedCarrier;
        }

        exhibit state operation : ElectroscopeOperation;

        constraint chargeDistribution {
            totalStoredCharge == terminal.terminalCharge + stem.stemCharge + leaves.leftLeaf.leafCharge + leaves.rightLeaf.leafCharge
        }

        constraint equalLeafCharge {
            leaves.leftLeaf.leafCharge == leaves.rightLeaf.leafCharge
        }

        constraint potentialRelation {
            terminalPotential == totalStoredCharge / terminal.capacitanceToEnvironment
        }

        constraint deflectionClassification {
            visualOutput.deflectionSignal.leafAngle < 1 [SI::degree] implies
                visualOutput.deflectionSignal.indication == IndicationMode::noDeflection
        }

        constraint weakIndication {
            visualOutput.deflectionSignal.leafAngle >= 1 [SI::degree] and
            visualOutput.deflectionSignal.leafAngle < 10 [SI::degree] implies
                visualOutput.deflectionSignal.indication == IndicationMode::weakDeflection
        }

        constraint moderateIndication {
            visualOutput.deflectionSignal.leafAngle >= 10 [SI::degree] and
            visualOutput.deflectionSignal.leafAngle < 25 [SI::degree] implies
                visualOutput.deflectionSignal.indication == IndicationMode::moderateDeflection
        }

        constraint strongIndication {
            visualOutput.deflectionSignal.leafAngle >= 25 [SI::degree] and
            visualOutput.deflectionSignal.leafAngle <= 45 [SI::degree] implies
                visualOutput.deflectionSignal.indication == IndicationMode::strongDeflection
        }

        satisfy PrimaryFunctionRequirement by this;
        satisfy DetectElectrostaticChargeRequirement by this;
        satisfy IsolationRequirement by this;
        satisfy DischargeRequirement by this;
    }

    part electroscope : SimpleLeafElectroscope;

    part testChargedRod {
        attribute netCharge : ElectricCharge = 2.0e-8 [SI::coulomb];
        attribute polarity : ChargePolarity = ChargePolarity::negative;
        attribute surfacePotential : ElectricPotential = -6000 [SI::volt];
        attribute distanceFromTerminal : Length = 0.025 [SI::meter];

        port fieldOutput : FieldSensePort;
        port contactOutput : ChargePort;
    }

    part earthGround {
        attribute potential : ElectricPotential = 0 [SI::volt];
        port groundOutput : GroundPort;
    }

    connect testChargedRod.contactOutput to electroscope.sensingTerminal;
    connect testChargedRod.fieldOutput to electroscope.fieldSensor;
    connect earthGround.groundOutput to electroscope.groundConnection;

    requirement electroscopeSystemPurpose {
        doc /* The modeled system shall provide a high-level physical indication of electrostatic charge by allowing charge or electrostatic influence at a conductive terminal to create like charge on two lightweight leaves, causing them to repel and visibly separate. */
        subject electroscope;

        require constraint {
            electroscope.visualOutput.deflectionSignal.leafAngle > 0 [SI::degree] implies
            electroscope.detectedChargeMagnitude >= electroscope.minimumDetectableCharge
        }
    }

    satisfy electroscopeSystemPurpose by electroscope;
}