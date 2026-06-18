package CompressionGarmentSpecification {

    import ScalarValues::*;
    import SI::*;

    unit def mm;
    unit def cm;
    unit def kPa;
    unit def N;
    unit def degC;
    unit def percent;
    unit def min;
    unit def cycle;

    attribute def Length :> Real {
        unit mm;
    }

    attribute def Circumference :> Length {
        unit mm;
    }

    attribute def Pressure :> Real {
        unit kPa;
    }

    attribute def Force :> Real {
        unit N;
    }

    attribute def Temperature :> Real {
        unit degC;
    }

    attribute def RelativeHumidity :> Real {
        unit percent;
    }

    attribute def TimeDuration :> Real {
        unit min;
    }

    attribute def CycleCount :> Real {
        unit cycle;
    }

    attribute def ElasticModulus :> Real {
        unit kPa;
    }

    enum def GarmentSize {
        enum extraSmall;
        enum small;
        enum medium;
        enum large;
        enum extraLarge;
    }

    enum def LimbSide {
        enum left;
        enum right;
        enum bilateral;
    }

    enum def GarmentCondition {
        enum newCondition;
        enum serviceable;
        enum worn;
        enum damaged;
        enum retired;
    }

    enum def FitAssessment {
        enum tooLoose;
        enum acceptable;
        enum tooTight;
        enum unsafe;
    }

    item def LimbGeometry {
        attribute distalCircumference : Circumference;
        attribute middleCircumference : Circumference;
        attribute proximalCircumference : Circumference;
        attribute limbLength : Length;
        attribute limbSide : LimbSide;
    }

    item def CompressionPressure {
        attribute distalPressure : Pressure;
        attribute middlePressure : Pressure;
        attribute proximalPressure : Pressure;
        attribute peakLocalizedPressure : Pressure;
    }

    item def SkinCondition {
        attribute skinTemperature : Temperature;
        attribute skinHumidity : RelativeHumidity;
        attribute rednessIndex : Real;
        attribute painScore : Real;
        attribute numbnessReported : Boolean;
    }

    item def FitCommand {
        attribute requestedDonning : Boolean;
        attribute requestedRemoval : Boolean;
        attribute requestedAdjustment : Boolean;
    }

    item def FitFeedback {
        attribute fitAssessment : FitAssessment;
        attribute measuredPressure : CompressionPressure;
        attribute userComfortScore : Real;
    }

    item def MoistureVapor {
        attribute relativeHumidity : RelativeHumidity;
        attribute temperature : Temperature;
    }

    item def BodyHeat {
        attribute temperature : Temperature;
    }

    item def MechanicalSupport {
        attribute circumferentialForce : Force;
        attribute interfacePressure : CompressionPressure;
    }

    port def CompressionInterfacePort {
        in item limbGeometry : LimbGeometry;
        in item skinCondition : SkinCondition;
        out item mechanicalSupport : MechanicalSupport;
        out item pressureProfile : CompressionPressure;
    }

    port def ComfortExchangePort {
        in item bodyHeat : BodyHeat;
        in item moistureVapor : MoistureVapor;
        out item ventedMoisture : MoistureVapor;
        out item dissipatedHeat : BodyHeat;
    }

    port def UserFitPort {
        in item command : FitCommand;
        out item feedback : FitFeedback;
    }

    port def EnvironmentPort {
        in item ambientHeat : BodyHeat;
        in item ambientMoisture : MoistureVapor;
        out item evaporatedMoisture : MoistureVapor;
    }

    constraint def GraduatedCompressionRule {
        in distal : Pressure;
        in middle : Pressure;
        in proximal : Pressure;
        in peak : Pressure;

        require distal > middle;
        require middle > proximal;
        require distal >= 2.4 [kPa];
        require distal <= 5.3 [kPa];
        require middle >= 2.0 [kPa];
        require middle <= 4.6 [kPa];
        require proximal >= 1.3 [kPa];
        require proximal <= 3.3 [kPa];
        require peak <= 6.7 [kPa];
    }

    constraint def ComfortSafetyRule {
        in skinTemperature : Temperature;
        in skinHumidity : RelativeHumidity;
        in painScore : Real;
        in numbnessReported : Boolean;

        require skinTemperature >= 18.0 [degC];
        require skinTemperature <= 38.0 [degC];
        require skinHumidity <= 85.0 [percent];
        require painScore <= 3.0;
        require numbnessReported == false;
    }

    constraint def SizingCompatibilityRule {
        in garmentDistalCircumference : Circumference;
        in garmentMiddleCircumference : Circumference;
        in garmentProximalCircumference : Circumference;
        in limbDistalCircumference : Circumference;
        in limbMiddleCircumference : Circumference;
        in limbProximalCircumference : Circumference;

        require garmentDistalCircumference < limbDistalCircumference;
        require garmentMiddleCircumference < limbMiddleCircumference;
        require garmentProximalCircumference < limbProximalCircumference;
    }

    action def MeasureLimb {
        in item limb : LimbGeometry;
        out item measuredGeometry : LimbGeometry;
    }

    action def SelectGarmentSize {
        in item measuredGeometry : LimbGeometry;
        out size : GarmentSize;
    }

    action def DonGarment {
        in item command : FitCommand;
        in item limbGeometry : LimbGeometry;
        out item fittedGeometry : LimbGeometry;
    }

    action def GenerateGraduatedPressure {
        in item limbGeometry : LimbGeometry;
        out item pressureProfile : CompressionPressure;

        assert constraint GraduatedCompressionRule {
            distal = pressureProfile.distalPressure;
            middle = pressureProfile.middlePressure;
            proximal = pressureProfile.proximalPressure;
            peak = pressureProfile.peakLocalizedPressure;
        }
    }

    action def VentHeatAndMoisture {
        in item bodyHeat : BodyHeat;
        in item moistureVapor : MoistureVapor;
        out item dissipatedHeat : BodyHeat;
        out item ventedMoisture : MoistureVapor;
    }

    action def AssessFitAndComfort {
        in item pressureProfile : CompressionPressure;
        in item skinCondition : SkinCondition;
        out item feedback : FitFeedback;

        assert constraint ComfortSafetyRule {
            skinTemperature = skinCondition.skinTemperature;
            skinHumidity = skinCondition.skinHumidity;
            painScore = skinCondition.painScore;
            numbnessReported = skinCondition.numbnessReported;
        }
    }

    action def RemoveGarment {
        in item command : FitCommand;
        out removed : Boolean;
    }

    state def CompressionGarmentLifecycle {
        state stored;
        state beingDonned;
        state fitted;
        state providingCompression;
        state adjustmentNeeded;
        state beingRemoved;
        state retired;

        initial then stored;

        transition stored_to_beingDonned
            first stored
            accept FitCommand
            if command.requestedDonning == true
            then beingDonned;

        transition beingDonned_to_fitted
            first beingDonned
            then fitted;

        transition fitted_to_providingCompression
            first fitted
            then providingCompression;

        transition providingCompression_to_adjustmentNeeded
            first providingCompression
            accept FitFeedback
            if feedback.fitAssessment == FitAssessment::tooLoose or feedback.fitAssessment == FitAssessment::tooTight
            then adjustmentNeeded;

        transition adjustmentNeeded_to_providingCompression
            first adjustmentNeeded
            accept FitFeedback
            if feedback.fitAssessment == FitAssessment::acceptable
            then providingCompression;

        transition providingCompression_to_beingRemoved
            first providingCompression
            accept FitCommand
            if command.requestedRemoval == true
            then beingRemoved;

        transition beingRemoved_to_stored
            first beingRemoved
            then stored;

        transition providingCompression_to_retired
            first providingCompression
            if serviceCycles > 200.0 [cycle]
            then retired;
    }

    part def TextileLayer {
        attribute thickness : Length;
        attribute elasticModulus : ElasticModulus;
        attribute moistureTransmissionRate : Real;
        attribute airPermeability : Real;
        attribute washableCycles : CycleCount;
        port comfortPort : ComfortExchangePort;
    }

    part def ElasticYarn {
        attribute relaxedLength : Length;
        attribute stretchedLength : Length;
        attribute circumferentialTension : Force;
        attribute recoveryRatio : Real;
    }

    part def Seam {
        attribute seamWidth : Length;
        attribute seamStrength : Force;
        attribute flatlock : Boolean;
    }

    part def AntiSlipBand {
        attribute width : Length;
        attribute gripForce : Force;
        attribute skinContactSafe : Boolean;
    }

    part def ClosureSystem {
        attribute adjustableRange : Length;
        attribute maximumClosingForce : Force;
        port userPort : UserFitPort;
    }

    part def CompressionZone {
        attribute nominalCircumference : Circumference;
        attribute targetPressure : Pressure;
        attribute maximumAllowedPressure : Pressure;
        attribute zoneLength : Length;
        attribute compressionGradientRank : Integer;
        part elasticYarn : ElasticYarn;
        port compressionPort : CompressionInterfacePort;
        port comfortPort : ComfortExchangePort;
    }

    part def LimbSegment {
        attribute side : LimbSide;
        attribute distalCircumference : Circumference;
        attribute middleCircumference : Circumference;
        attribute proximalCircumference : Circumference;
        attribute limbLength : Length;
        attribute skinTemperature : Temperature;
        attribute skinHumidity : RelativeHumidity;
        port tissueInterface : CompressionInterfacePort;
        port comfortInterface : ComfortExchangePort;
    }

    part def CompressionGarment {
        attribute size : GarmentSize;
        attribute condition : GarmentCondition;
        attribute serviceCycles : CycleCount;
        attribute intendedWearDuration : TimeDuration;
        attribute appliedDistalPressure : Pressure;
        attribute appliedMiddlePressure : Pressure;
        attribute appliedProximalPressure : Pressure;
        attribute peakLocalizedPressure : Pressure;

        part distalZone : CompressionZone {
            attribute nominalCircumference = 210.0 [mm];
            attribute targetPressure = 4.0 [kPa];
            attribute maximumAllowedPressure = 5.3 [kPa];
            attribute zoneLength = 120.0 [mm];
            attribute compressionGradientRank = 1;
        }

        part middleZone : CompressionZone {
            attribute nominalCircumference = 255.0 [mm];
            attribute targetPressure = 3.2 [kPa];
            attribute maximumAllowedPressure = 4.6 [kPa];
            attribute zoneLength = 140.0 [mm];
            attribute compressionGradientRank = 2;
        }

        part proximalZone : CompressionZone {
            attribute nominalCircumference = 315.0 [mm];
            attribute targetPressure = 2.2 [kPa];
            attribute maximumAllowedPressure = 3.3 [kPa];
            attribute zoneLength = 150.0 [mm];
            attribute compressionGradientRank = 3;
        }

        part outerTextile : TextileLayer {
            attribute thickness = 0.9 [mm];
            attribute elasticModulus = 95.0 [kPa];
            attribute moistureTransmissionRate = 0.78;
            attribute airPermeability = 0.72;
            attribute washableCycles = 200.0 [cycle];
        }

        part innerLiner : TextileLayer {
            attribute thickness = 0.6 [mm];
            attribute elasticModulus = 60.0 [kPa];
            attribute moistureTransmissionRate = 0.88;
            attribute airPermeability = 0.80;
            attribute washableCycles = 200.0 [cycle];
        }

        part proximalAntiSlipBand : AntiSlipBand {
            attribute width = 35.0 [mm];
            attribute gripForce = 2.5 [N];
            attribute skinContactSafe = true;
        }

        part longitudinalSeam : Seam {
            attribute seamWidth = 5.0 [mm];
            attribute seamStrength = 80.0 [N];
            attribute flatlock = true;
        }

        part adjustableClosure : ClosureSystem {
            attribute adjustableRange = 35.0 [mm];
            attribute maximumClosingForce = 25.0 [N];
        }

        port innerCompressionPort : CompressionInterfacePort;
        port outerEnvironmentPort : EnvironmentPort;
        port userPort : UserFitPort;
        port comfortPort : ComfortExchangePort;

        connection distalCompressionCoupling
            connect distalZone.compressionPort to innerCompressionPort;

        connection middleCompressionCoupling
            connect middleZone.compressionPort to innerCompressionPort;

        connection proximalCompressionCoupling
            connect proximalZone.compressionPort to innerCompressionPort;

        connection linerComfortCoupling
            connect innerLiner.comfortPort to comfortPort;

        connection textileVentCoupling
            connect outerTextile.comfortPort to comfortPort;

        connection closureUserCoupling
            connect adjustableClosure.userPort to userPort;

        perform action generateCompression : GenerateGraduatedPressure;
        perform action ventComfort : VentHeatAndMoisture;
        perform action assessFit : AssessFitAndComfort;

        exhibit state lifecycle : CompressionGarmentLifecycle;

        assert constraint GraduatedCompressionRule {
            distal = appliedDistalPressure;
            middle = appliedMiddlePressure;
            proximal = appliedProximalPressure;
            peak = peakLocalizedPressure;
        }
    }

    part def Wearer {
        attribute comfortScore : Real;
        attribute painScore : Real;
        part targetLimb : LimbSegment;
        port bodyCompressionPort : CompressionInterfacePort;
        port bodyComfortPort : ComfortExchangePort;

        connection limbCompressionConnection
            connect targetLimb.tissueInterface to bodyCompressionPort;

        connection limbComfortConnection
            connect targetLimb.comfortInterface to bodyComfortPort;
    }

    part def CompressionGarmentSystem {
        attribute systemName : String = "Compression garment";
        attribute primaryFunction : String = "Provide externally applied graduated circumferential compression to a body segment to support fluid return, reduce edema tendency, and maintain comfort and mobility during wear.";

        part garment : CompressionGarment {
            attribute size = GarmentSize::medium;
            attribute condition = GarmentCondition::serviceable;
            attribute serviceCycles = 0.0 [cycle];
            attribute intendedWearDuration = 480.0 [min];
            attribute appliedDistalPressure = 4.0 [kPa];
            attribute appliedMiddlePressure = 3.2 [kPa];
            attribute appliedProximalPressure = 2.2 [kPa];
            attribute peakLocalizedPressure = 4.8 [kPa];
        }

        part wearer : Wearer {
            attribute comfortScore = 8.0;
            attribute painScore = 0.0;
            part targetLimb {
                attribute side = LimbSide::left;
                attribute distalCircumference = 235.0 [mm];
                attribute middleCircumference = 285.0 [mm];
                attribute proximalCircumference = 350.0 [mm];
                attribute limbLength = 410.0 [mm];
                attribute skinTemperature = 33.0 [degC];
                attribute skinHumidity = 55.0 [percent];
            }
        }

        port userInteraction : UserFitPort;
        port environment : EnvironmentPort;

        connection garmentToBodyCompression
            connect garment.innerCompressionPort to wearer.bodyCompressionPort;

        connection garmentToBodyComfort
            connect garment.comfortPort to wearer.bodyComfortPort;

        connection garmentToUser
            connect garment.userPort to userInteraction;

        connection garmentToEnvironment
            connect garment.outerEnvironmentPort to environment;

        perform action measureLimb : MeasureLimb;
        perform action selectSize : SelectGarmentSize;
        perform action donGarment : DonGarment;
        perform action provideGraduatedCompression : GenerateGraduatedPressure;
        perform action removeGarment : RemoveGarment;

        assert constraint SizingCompatibilityRule {
            garmentDistalCircumference = garment.distalZone.nominalCircumference;
            garmentMiddleCircumference = garment.middleZone.nominalCircumference;
            garmentProximalCircumference = garment.proximalZone.nominalCircumference;
            limbDistalCircumference = wearer.targetLimb.distalCircumference;
            limbMiddleCircumference = wearer.targetLimb.middleCircumference;
            limbProximalCircumference = wearer.targetLimb.proximalCircumference;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The compression garment system shall provide graduated circumferential compression to a target body segment at a high level, with higher pressure distally and lower pressure proximally, in order to support venous and lymphatic fluid return and reduce edema tendency while allowing normal mobility. */

        subject system : CompressionGarmentSystem;

        require constraint {
            system.garment.appliedDistalPressure > system.garment.appliedMiddlePressure;
            system.garment.appliedMiddlePressure > system.garment.appliedProximalPressure;
            system.primaryFunction == "Provide externally applied graduated circumferential compression to a body segment to support fluid return, reduce edema tendency, and maintain comfort and mobility during wear.";
        }
    }

    requirement def PressurePerformanceRequirement {
        doc /* The garment shall maintain therapeutic interface pressure within defined safe ranges over distal, middle, and proximal zones during intended wear. */

        subject garment : CompressionGarment;

        require constraint GraduatedCompressionRule {
            distal = garment.appliedDistalPressure;
            middle = garment.appliedMiddlePressure;
            proximal = garment.appliedProximalPressure;
            peak = garment.peakLocalizedPressure;
        }
    }

    requirement def ComfortRequirement {
        doc /* The garment shall manage heat and moisture at the skin interface and shall not create pain, numbness, or excessive humidity during normal use. */

        subject wearer : Wearer;

        require constraint ComfortSafetyRule {
            skinTemperature = wearer.targetLimb.skinTemperature;
            skinHumidity = wearer.targetLimb.skinHumidity;
            painScore = wearer.painScore;
            numbnessReported = false;
        }
    }

    requirement def FitCompatibilityRequirement {
        doc /* The selected garment size shall be smaller than the measured limb circumferences in each compression zone so that elastic recovery generates circumferential pressure. */

        subject system : CompressionGarmentSystem;

        require constraint SizingCompatibilityRule {
            garmentDistalCircumference = system.garment.distalZone.nominalCircumference;
            garmentMiddleCircumference = system.garment.middleZone.nominalCircumference;
            garmentProximalCircumference = system.garment.proximalZone.nominalCircumference;
            limbDistalCircumference = system.wearer.targetLimb.distalCircumference;
            limbMiddleCircumference = system.wearer.targetLimb.middleCircumference;
            limbProximalCircumference = system.wearer.targetLimb.proximalCircumference;
        }
    }

    requirement def DurabilityRequirement {
        doc /* The garment shall remain serviceable for at least 200 normal wash and wear cycles while preserving elastic recovery and seam integrity. */

        subject garment : CompressionGarment;

        require constraint {
            garment.outerTextile.washableCycles >= 200.0 [cycle];
            garment.innerLiner.washableCycles >= 200.0 [cycle];
            garment.longitudinalSeam.seamStrength >= 60.0 [N];
            garment.condition != GarmentCondition::damaged;
        }
    }

    requirement def UsabilityRequirement {
        doc /* The wearer or caregiver shall be able to don, adjust, and remove the garment through the user fit interface without tools. */

        subject garment : CompressionGarment;

        require constraint {
            garment.adjustableClosure.adjustableRange >= 20.0 [mm];
            garment.adjustableClosure.maximumClosingForce <= 30.0 [N];
        }
    }

    satisfy PrimaryFunctionRequirement by CompressionGarmentSystem::provideGraduatedCompression;
    satisfy PressurePerformanceRequirement by CompressionGarment::generateCompression;
    satisfy ComfortRequirement by CompressionGarment::ventComfort;
    satisfy FitCompatibilityRequirement by CompressionGarmentSystem::selectSize;
    satisfy DurabilityRequirement by CompressionGarment::outerTextile;
    satisfy DurabilityRequirement by CompressionGarment::innerLiner;
    satisfy DurabilityRequirement by CompressionGarment::longitudinalSeam;
    satisfy UsabilityRequirement by CompressionGarment::adjustableClosure;

}
