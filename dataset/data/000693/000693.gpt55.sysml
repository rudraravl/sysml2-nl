package MicroneedleTransdermalTherapyModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def MicroliterValue :> ISQ::volume {
        doc /* Volume measured in microliters. */
        :>> unit = SI::microlitre;
    }

    attribute def MilligramValue :> ISQ::mass {
        doc /* Mass measured in milligrams. */
        :>> unit = SI::milligram;
    }

    attribute def MilligramPerMilliliterValue :> ISQ::massConcentration {
        doc /* Drug concentration measured in milligrams per milliliter. */
        :>> unit = SI::milligram / SI::millilitre;
    }

    attribute def KilopascalValue :> ISQ::pressure {
        doc /* Pressure measured in kilopascals. */
        :>> unit = SI::kilopascal;
    }

    attribute def MicrometerValue :> ISQ::length {
        doc /* Length measured in micrometers. */
        :>> unit = SI::micrometre;
    }

    attribute def SquareCentimeterValue :> ISQ::area {
        doc /* Area measured in square centimeters. */
        :>> unit = SI::centimetre * SI::centimetre;
    }

    attribute def MilliampereHourValue :> ISQ::electricCharge {
        doc /* Battery capacity measured in milliampere-hours. */
        :>> unit = SI::milliampere * SI::hour;
    }

    attribute def MilliwattValue :> ISQ::power {
        doc /* Electrical power measured in milliwatts. */
        :>> unit = SI::milliwatt;
    }

    attribute def SecondValue :> ISQ::time {
        doc /* Time measured in seconds. */
        :>> unit = SI::second;
    }

    attribute def CelsiusValue :> ISQ::thermodynamicTemperature {
        doc /* Temperature measured in degrees Celsius. */
        :>> unit = SI::degreeCelsius;
    }

    attribute def PercentValue :> ScalarValues::Real {
        doc /* Dimensionless percentage value from 0 to 100 percent. */
    }

    enum def TherapyMode {
        enum standby;
        enum armed;
        enum inserting;
        enum priming;
        enum delivering;
        enum verifying;
        enum complete;
        enum fault;
        enum removed;
    }

    enum def FaultType {
        enum noFault;
        enum occlusion;
        enum lowBattery;
        enum leakage;
        enum insufficientSkinContact;
        enum overPressure;
        enum doseDeviation;
        enum sensorFailure;
        enum expiredCartridge;
    }

    item def DrugFormulation {
        doc /* Sterile liquid therapeutic formulation intended for intradermal or transdermal administration through microneedle channels. */
        attribute activeIngredientName : String;
        attribute concentration : MilligramPerMilliliterValue;
        attribute containedVolume : MicroliterValue;
        attribute prescribedDoseMass : MilligramValue;
        attribute viscosityClass : String;
        attribute sterile : Boolean;
        attribute expirationRemainingTime : SecondValue;
    }

    item def ElectricalPower {
        attribute voltage : ISQ::electricPotential;
        attribute availablePower : MilliwattValue;
        attribute capacityRemaining : MilliampereHourValue;
    }

    item def PumpCommand {
        attribute targetFlowVolume : MicroliterValue;
        attribute targetInfusionTime : SecondValue;
        attribute maximumAllowedPressure : KilopascalValue;
        attribute enable : Boolean;
    }

    item def InsertionCommand {
        attribute targetPenetrationDepth : MicrometerValue;
        attribute insertionDuration : SecondValue;
        attribute enable : Boolean;
    }

    item def FlowMeasurement {
        attribute deliveredVolume : MicroliterValue;
        attribute instantaneousPressure : KilopascalValue;
        attribute elapsedDeliveryTime : SecondValue;
        attribute bubbleDetected : Boolean;
    }

    item def ContactMeasurement {
        attribute contactArea : SquareCentimeterValue;
        attribute normalForcePercentOfTarget : PercentValue;
        attribute skinTemperature : CelsiusValue;
        attribute contactStable : Boolean;
    }

    item def AlarmSignal {
        attribute fault : FaultType;
        attribute severityPercent : PercentValue;
        attribute message : String;
    }

    item def TherapyStatus {
        attribute mode : TherapyMode;
        attribute deliveredVolume : MicroliterValue;
        attribute deliveredDoseMass : MilligramValue;
        attribute completionPercent : PercentValue;
        attribute activeFault : FaultType;
    }

    port def DrugOutletPort {
        out item drug : DrugFormulation;
        attribute outletPressure : KilopascalValue;
    }

    port def DrugInletPort {
        in item drug : DrugFormulation;
        attribute inletPressure : KilopascalValue;
    }

    port def DrugSkinDeliveryPort {
        out item drug : DrugFormulation;
        attribute deliveryPressure : KilopascalValue;
    }

    port def SkinAbsorptionPort {
        in item drug : DrugFormulation;
        attribute acceptedVolume : MicroliterValue;
    }

    port def PowerSourcePort {
        out item power : ElectricalPower;
    }

    port def PowerLoadPort {
        in item power : ElectricalPower;
    }

    port def PumpCommandPort {
        in item command : PumpCommand;
    }

    port def PumpControlPort {
        out item command : PumpCommand;
    }

    port def InsertionCommandInPort {
        in item command : InsertionCommand;
    }

    port def InsertionCommandOutPort {
        out item command : InsertionCommand;
    }

    port def FlowMeasurementOutPort {
        out item measurement : FlowMeasurement;
    }

    port def FlowMeasurementInPort {
        in item measurement : FlowMeasurement;
    }

    port def ContactMeasurementOutPort {
        out item measurement : ContactMeasurement;
    }

    port def ContactMeasurementInPort {
        in item measurement : ContactMeasurement;
    }

    port def AlarmOutPort {
        out item alarm : AlarmSignal;
    }

    port def AlarmInPort {
        in item alarm : AlarmSignal;
    }

    port def StatusOutPort {
        out item status : TherapyStatus;
    }

    port def StatusInPort {
        in item status : TherapyStatus;
    }

    part def DrugCartridge {
        doc /* Replaceable sterile reservoir containing the liquid drug formulation. */
        attribute nominalFillVolume : MicroliterValue = 500;
        attribute residualVolume : MicroliterValue = 500;
        attribute drugConcentration : MilligramPerMilliliterValue = 10;
        attribute sterileBarrierIntact : Boolean = true;
        attribute expired : Boolean = false;

        port outlet : DrugOutletPort;

        item containedDrug : DrugFormulation {
            attribute activeIngredientName = "model therapeutic";
            attribute concentration = 10;
            attribute containedVolume = 500;
            attribute prescribedDoseMass = 1;
            attribute viscosityClass = "low-viscosity aqueous";
            attribute sterile = true;
            attribute expirationRemainingTime = 15552000;
        }
    }

    part def MicroPumpActuator {
        doc /* Miniature electro-mechanical pump that meters drug volume from the cartridge to the microneedle manifold. */
        attribute maximumStrokeVolume : MicroliterValue = 2;
        attribute maximumOperatingPressure : KilopascalValue = 80;
        attribute meteringAccuracyPercent : PercentValue = 5;
        attribute primed : Boolean = false;
        attribute enabled : Boolean = false;

        port inlet : DrugInletPort;
        port outlet : DrugOutletPort;
        port powerIn : PowerLoadPort;
        port commandIn : PumpCommandPort;
        port flowReportOut : FlowMeasurementOutPort;
        port alarmOut : AlarmOutPort;
    }

    part def FlowAndPressureSensor {
        doc /* Inline sensor assembly used to estimate delivered volume, detect occlusion, detect leakage, and detect bubbles. */
        attribute measurementAccuracyPercent : PercentValue = 3;
        attribute pressureLimitForOcclusion : KilopascalValue = 75;
        attribute bubbleDetectionEnabled : Boolean = true;

        port inlet : DrugInletPort;
        port outlet : DrugOutletPort;
        port powerIn : PowerLoadPort;
        port measurementOut : FlowMeasurementOutPort;
        port alarmOut : AlarmOutPort;
    }

    part def MicroneedleArray {
        doc /* Array of short sterile microneedles that creates shallow microchannels and distributes drug into viable epidermal or upper dermal tissue. */
        attribute needleCount : Integer = 121;
        attribute needleLength : MicrometerValue = 650;
        attribute needleTipDiameter : MicrometerValue = 25;
        attribute arrayArea : SquareCentimeterValue = 2;
        attribute targetPenetrationDepth : MicrometerValue = 450;
        attribute biocompatible : Boolean = true;
        attribute sterileAtUse : Boolean = true;
        attribute inserted : Boolean = false;

        port manifoldInlet : DrugInletPort;
        port skinDelivery : DrugSkinDeliveryPort;
        port powerIn : PowerLoadPort;
        port insertionCommandIn : InsertionCommandInPort;
        port contactMeasurementOut : ContactMeasurementOutPort;
        port alarmOut : AlarmOutPort;
    }

    part def SkinAdhesiveInterface {
        doc /* Medical adhesive and conformal contact layer that stabilizes the patch over the treatment site. */
        attribute adhesiveArea : SquareCentimeterValue = 12;
        attribute requiredContactArea : SquareCentimeterValue = 8;
        attribute skinContactStable : Boolean = false;
        attribute removableWithoutNeedleResidue : Boolean = true;

        port contactMeasurementOut : ContactMeasurementOutPort;
        port alarmOut : AlarmOutPort;
    }

    part def BatteryModule {
        doc /* Thin primary or rechargeable cell providing electrical power for controller, sensors, insertion actuator, and pump. */
        attribute nominalCapacity : MilliampereHourValue = 80;
        attribute remainingCapacity : MilliampereHourValue = 80;
        attribute maximumContinuousPower : MilliwattValue = 350;
        attribute lowBatteryThresholdPercent : PercentValue = 15;

        port powerOut : PowerSourcePort;
        port alarmOut : AlarmOutPort;
    }

    part def PatchController {
        doc /* Embedded controller that sequences application, insertion, priming, dose delivery, verification, fault handling, and status reporting. */
        attribute requestedDoseVolume : MicroliterValue = 100;
        attribute requestedInfusionTime : SecondValue = 600;
        attribute commandedPenetrationDepth : MicrometerValue = 450;
        attribute currentMode : TherapyMode = TherapyMode::standby;
        attribute activeFault : FaultType = FaultType::noFault;

        port powerIn : PowerLoadPort;
        port pumpCommandOut : PumpControlPort;
        port insertionCommandOut : InsertionCommandOutPort;
        port flowMeasurementIn : FlowMeasurementInPort;
        port contactMeasurementIn : ContactMeasurementInPort;
        port alarmIn : AlarmInPort;
        port statusOut : StatusOutPort;

        perform action therapyControl : ControlledMicroneedleDoseDelivery;
    }

    part def UserInterface {
        doc /* Simple patient or clinician interface providing start feedback, progress indication, and fault notification. */
        attribute startButtonEnabled : Boolean = true;
        attribute completionDisplayed : Boolean = false;
        attribute faultDisplayed : Boolean = false;

        port powerIn : PowerLoadPort;
        port statusIn : StatusInPort;
        port alarmIn : AlarmInPort;
    }

    part def PatientSkin {
        doc /* External skin region receiving the microneedle array and absorbing delivered drug through created microchannels. */
        attribute skinSite : String = "upper arm";
        attribute surfaceTemperature : CelsiusValue = 33;
        attribute maximumComfortablePenetrationDepth : MicrometerValue = 700;
        attribute acceptedDoseVolume : MicroliterValue = 0;

        port absorptionInterface : SkinAbsorptionPort;
    }

    part def MicroneedleTherapyPatch {
        doc /* Wearable microneedle-based transdermal therapy patch whose primary high-level function is to administer a controlled micro-dose of sterile drug across the skin barrier with minimal pain and automated verification. */
        attribute prescribedDoseVolume : MicroliterValue = 100;
        attribute prescribedDoseMass : MilligramValue = 1;
        attribute nominalDeliveryDuration : SecondValue = 600;
        attribute allowableDoseErrorPercent : PercentValue = 10;
        attribute mode : TherapyMode = TherapyMode::standby;
        attribute fault : FaultType = FaultType::noFault;

        part cartridge : DrugCartridge;
        part pump : MicroPumpActuator;
        part flowSensor : FlowAndPressureSensor;
        part microneedles : MicroneedleArray;
        part adhesive : SkinAdhesiveInterface;
        part battery : BatteryModule;
        part controller : PatchController;
        part userInterface : UserInterface;

        port skinDelivery : DrugSkinDeliveryPort;
        port statusOut : StatusOutPort;
        port alarmOut : AlarmOutPort;

        connect cartridge.outlet to pump.inlet;
        connect pump.outlet to flowSensor.inlet;
        connect flowSensor.outlet to microneedles.manifoldInlet;
        connect microneedles.skinDelivery to skinDelivery;

        connect battery.powerOut to pump.powerIn;
        connect battery.powerOut to flowSensor.powerIn;
        connect battery.powerOut to microneedles.powerIn;
        connect battery.powerOut to controller.powerIn;
        connect battery.powerOut to userInterface.powerIn;

        connect controller.pumpCommandOut to pump.commandIn;
        connect controller.insertionCommandOut to microneedles.insertionCommandIn;

        connect pump.flowReportOut to controller.flowMeasurementIn;
        connect flowSensor.measurementOut to controller.flowMeasurementIn;
        connect microneedles.contactMeasurementOut to controller.contactMeasurementIn;
        connect adhesive.contactMeasurementOut to controller.contactMeasurementIn;

        connect pump.alarmOut to controller.alarmIn;
        connect flowSensor.alarmOut to controller.alarmIn;
        connect microneedles.alarmOut to controller.alarmIn;
        connect adhesive.alarmOut to controller.alarmIn;
        connect battery.alarmOut to controller.alarmIn;

        connect controller.statusOut to userInterface.statusIn;
        connect controller.statusOut to statusOut;

        connect pump.alarmOut to alarmOut;
        connect flowSensor.alarmOut to alarmOut;
        connect microneedles.alarmOut to alarmOut;
        connect adhesive.alarmOut to alarmOut;
        connect battery.alarmOut to alarmOut;
        connect controller.alarmIn to userInterface.alarmIn;

        perform action deliverDose : ControlledMicroneedleDoseDelivery;
        exhibit state lifecycle : MicroneedlePatchLifecycle;
    }

    action def VerifySkinContact {
        in item contact : ContactMeasurement;
        out item acceptableContact : ContactMeasurement;

        constraint contactAreaSufficient {
            contact.contactArea >= 8;
        }

        constraint contactStable {
            contact.contactStable == true;
        }
    }

    action def InsertMicroneedles {
        in item command : InsertionCommand;
        out item contact : ContactMeasurement;

        constraint penetrationLimit {
            command.targetPenetrationDepth <= 700;
        }

        constraint insertionEnabled {
            command.enable == true;
        }
    }

    action def PrimeFluidPath {
        in item drugIn : DrugFormulation;
        out item drugOut : DrugFormulation;

        attribute primeVolume : MicroliterValue = 10;
        attribute maximumPrimePressure : KilopascalValue = 50;
    }

    action def InfuseControlledDose {
        in item command : PumpCommand;
        in item drugIn : DrugFormulation;
        out item drugOut : DrugFormulation;
        out item measurement : FlowMeasurement;

        constraint infusionPressureSafe {
            measurement.instantaneousPressure <= command.maximumAllowedPressure;
        }

        constraint infusedVolumeTarget {
            measurement.deliveredVolume <= command.targetFlowVolume;
        }
    }

    action def VerifyDoseDelivery {
        in item measurement : FlowMeasurement;
        out item status : TherapyStatus;

        attribute targetDoseVolume : MicroliterValue = 100;
        attribute allowedDoseError : PercentValue = 10;

        constraint deliveredVolumeWithinTolerance {
            measurement.deliveredVolume >= 90 and measurement.deliveredVolume <= 110;
        }

        constraint noBubble {
            measurement.bubbleDetected == false;
        }
    }

    action def ControlledMicroneedleDoseDelivery {
        doc /* High-level therapy behavior: confirm patch contact, insert microneedles into shallow skin layers, prime the sterile fluid path, meter the prescribed micro-dose, verify delivered volume, and report completion or fault. */

        in item initialDrug : DrugFormulation;
        in item initialContact : ContactMeasurement;
        out item deliveredDrug : DrugFormulation;
        out item therapyStatus : TherapyStatus;

        attribute targetDoseVolume : MicroliterValue = 100;
        attribute targetDoseMass : MilligramValue = 1;
        attribute targetInfusionTime : SecondValue = 600;
        attribute maximumDeliveryPressure : KilopascalValue = 75;
        attribute targetPenetrationDepth : MicrometerValue = 450;

        action checkContact : VerifySkinContact;
        action insertArray : InsertMicroneedles;
        action primePath : PrimeFluidPath;
        action infuseDose : InfuseControlledDose;
        action verifyDose : VerifyDoseDelivery;

        first start;
        then checkContact;
        then insertArray;
        then primePath;
        then infuseDose;
        then verifyDose;
        then done;

        flow initialContact to checkContact.contact;
        flow initialDrug to primePath.drugIn;
        flow primePath.drugOut to infuseDose.drugIn;
        flow infuseDose.drugOut to deliveredDrug;
        flow infuseDose.measurement to verifyDose.measurement;
        flow verifyDose.status to therapyStatus;
    }

    state def MicroneedlePatchLifecycle {
        doc /* Operational lifecycle for a microneedle therapy patch. */

        state packaged;
        state standby;
        state armed;
        state contactCheck;
        state inserting;
        state priming;
        state delivering;
        state verifying;
        state complete;
        state faulted;
        state removed;

        transition initial_to_packaged first packaged;

        transition unpacked
            first packaged
            then standby;

        transition armAfterApplication
            first standby
            accept ContactMeasurement
            then armed;

        transition beginContactVerification
            first armed
            then contactCheck;

        transition contactAccepted
            first contactCheck
            then inserting;

        transition contactRejected
            first contactCheck
            then faulted;

        transition insertionComplete
            first inserting
            then priming;

        transition primingComplete
            first priming
            then delivering;

        transition deliveryComplete
            first delivering
            then verifying;

        transition doseVerified
            first verifying
            then complete;

        transition verificationFailed
            first verifying
            then faulted;

        transition occlusionDetected
            first delivering
            accept AlarmSignal
            then faulted;

        transition lowBatteryDetected
            first armed
            accept AlarmSignal
            then faulted;

        transition removeAfterComplete
            first complete
            then removed;

        transition removeAfterFault
            first faulted
            then removed;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall use a microneedle array to deliver a prescribed sterile therapeutic micro-dose across the skin barrier into superficial tissue with automated control and delivery verification. */
        subject patch : MicroneedleTherapyPatch;

        require constraint primaryDoseDelivery {
            patch.prescribedDoseVolume == 100;
        }

        require constraint highLevelFunctionAvailable {
            patch.microneedles.needleCount >= 100 and patch.cartridge.sterileBarrierIntact == true;
        }
    }

    requirement def DoseAccuracyRequirement {
        doc /* The patch shall deliver the prescribed dose volume within plus or minus ten percent under normal skin contact and non-occluded flow conditions. */
        subject patch : MicroneedleTherapyPatch;

        require constraint doseTolerance {
            patch.allowableDoseErrorPercent <= 10;
        }
    }

    requirement def NeedleDepthSafetyRequirement {
        doc /* The microneedles shall be short enough to target superficial skin layers and avoid deep tissue penetration. */
        subject patch : MicroneedleTherapyPatch;

        require constraint depthLimit {
            patch.microneedles.targetPenetrationDepth <= 700;
        }
    }

    requirement def SterilityRequirement {
        doc /* All drug-contacting components and the microneedle array shall remain sterile until use. */
        subject patch : MicroneedleTherapyPatch;

        require constraint sterileDrugPath {
            patch.cartridge.sterileBarrierIntact == true and patch.microneedles.sterileAtUse == true;
        }
    }

    requirement def OcclusionDetectionRequirement {
        doc /* The patch shall detect excessive delivery pressure and enter a fault state before pressure exceeds the safe operating limit. */
        subject patch : MicroneedleTherapyPatch;

        require constraint pressureFaultThreshold {
            patch.flowSensor.pressureLimitForOcclusion <= 75;
        }
    }

    requirement def PatientContactRequirement {
        doc /* The patch shall verify sufficient adhesive contact area before microneedle insertion and dose delivery. */
        subject patch : MicroneedleTherapyPatch;

        require constraint minimumContactArea {
            patch.adhesive.requiredContactArea >= 8;
        }
    }

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject patch = therapyContext.patch;
    }

    requirement doseAccuracy : DoseAccuracyRequirement {
        subject patch = therapyContext.patch;
    }

    requirement needleDepthSafety : NeedleDepthSafetyRequirement {
        subject patch = therapyContext.patch;
    }

    requirement sterility : SterilityRequirement {
        subject patch = therapyContext.patch;
    }

    requirement occlusionDetection : OcclusionDetectionRequirement {
        subject patch = therapyContext.patch;
    }

    requirement patientContact : PatientContactRequirement {
        subject patch = therapyContext.patch;
    }

    part therapyContext {
        doc /* Treatment context showing the microneedle therapy patch applied to patient skin. */

        part patch : MicroneedleTherapyPatch;
        part skin : PatientSkin;

        connect patch.skinDelivery to skin.absorptionInterface;

        satisfy primaryFunction by patch;
        satisfy doseAccuracy by patch.pump;
        satisfy doseAccuracy by patch.flowSensor;
        satisfy needleDepthSafety by patch.microneedles;
        satisfy sterility by patch.cartridge;
        satisfy sterility by patch.microneedles;
        satisfy occlusionDetection by patch.flowSensor;
        satisfy patientContact by patch.adhesive;
    }
}
