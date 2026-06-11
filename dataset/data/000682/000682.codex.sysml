package MedicalGownSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percentage :> Real {
        unit = "%";
    }

    attribute def Pressure :> Real {
        unit = "Pa";
    }

    attribute def AirPermeability :> Real {
        unit = "L/(m^2*s)";
    }

    attribute def HydrostaticPressure :> Real {
        unit = "cmH2O";
    }

    attribute def Length :> Real {
        unit = "m";
    }

    attribute def MassDensity :> Real {
        unit = "g/m^2";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    item def Wearer;
    item def HealthcareWorker :> Wearer;
    item def Patient;
    item def Contaminant {
        attribute particleDiameter : Length;
        attribute infectiousRisk : Percentage;
    }

    item def LiquidDroplet :> Contaminant {
        attribute volume : Real;
        attribute impactPressure : Pressure;
    }

    item def AirborneParticle :> Contaminant {
        attribute aerosolConcentration : Real;
    }

    item def CleanAir;
    item def BodyHeat;
    item def MoistureVapor;
    item def ClinicalWaste;
    item def MedicalGownPackage;

    port def BodyInterfacePort {
        in item wearer : Wearer;
        out item bodyHeat : BodyHeat;
        out item moistureVapor : MoistureVapor;
    }

    port def EnvironmentExposurePort {
        in item liquidDroplet : LiquidDroplet;
        in item airborneParticle : AirborneParticle;
        out item cleanAir : CleanAir;
    }

    port def ClosurePort {
        in item tyingForce;
        out item fitStatus;
    }

    port def DisposalPort {
        out item waste : ClinicalWaste;
    }

    part def BarrierLayer {
        attribute materialBasisWeight : MassDensity;
        attribute liquidResistance : HydrostaticPressure;
        attribute microbialFiltrationEfficiency : Percentage;
        attribute viralPenetrationResistance : Boolean;
        attribute breathableAirFlow : AirPermeability;

        port exterior : EnvironmentExposurePort;
        port interior : BodyInterfacePort;

        perform action repelLiquid {
            in item droplet : LiquidDroplet;
            out item rejectedDroplet : LiquidDroplet;
        }

        perform action filterParticles {
            in item particles : AirborneParticle;
            out item reducedParticles : AirborneParticle;
        }

        perform action passMoistureVapor {
            in item vapor : MoistureVapor;
            out item releasedVapor : MoistureVapor;
        }
    }

    part def SleeveAssembly {
        attribute sleeveLength : Length;
        attribute cuffElasticRecovery : Percentage;
        attribute wristSealPressure : Pressure;

        port armInterface : BodyInterfacePort;
        port exteriorExposure : EnvironmentExposurePort;
    }

    part def TorsoPanel {
        attribute chestCoverageWidth : Length;
        attribute bodyCoverageLength : Length;
        attribute overlapMargin : Length;

        port frontExposure : EnvironmentExposurePort;
        port bodyInterface : BodyInterfacePort;
    }

    part def NeckClosure {
        attribute tieLength : Length;
        attribute closureIntegrity : Percentage;

        port closure : ClosurePort;
    }

    part def WaistClosure {
        attribute tieLength : Length;
        attribute closureIntegrity : Percentage;

        port closure : ClosurePort;
    }

    part def Cuff {
        attribute cuffCircumference : Length;
        attribute sealIntegrity : Percentage;
    }

    part def Label {
        attribute protectionLevel : Integer;
        attribute sizeCode : String;
        attribute sterile : Boolean;
        attribute singleUse : Boolean;
    }

    part def MedicalGown {
        attribute protectionCoverage : Percentage;
        attribute donningTime : TimeDuration;
        attribute doffingTime : TimeDuration;
        attribute expectedUseDuration : TimeDuration;
        attribute sterile : Boolean;
        attribute reusable : Boolean;

        port wearerInterface : BodyInterfacePort;
        port exposureInterface : EnvironmentExposurePort;
        port neckClosurePort : ClosurePort;
        port waistClosurePort : ClosurePort;
        port disposalPort : DisposalPort;

        part frontBarrier : BarrierLayer {
            attribute materialBasisWeight = 42.0;
            attribute liquidResistance = 100.0;
            attribute microbialFiltrationEfficiency = 98.0;
            attribute viralPenetrationResistance = true;
            attribute breathableAirFlow = 30.0;
        }

        part rearBarrier : BarrierLayer {
            attribute materialBasisWeight = 35.0;
            attribute liquidResistance = 60.0;
            attribute microbialFiltrationEfficiency = 95.0;
            attribute viralPenetrationResistance = true;
            attribute breathableAirFlow = 45.0;
        }

        part torsoPanel : TorsoPanel {
            attribute chestCoverageWidth = 0.72;
            attribute bodyCoverageLength = 1.18;
            attribute overlapMargin = 0.16;
        }

        part leftSleeve : SleeveAssembly {
            attribute sleeveLength = 0.64;
            attribute cuffElasticRecovery = 92.0;
            attribute wristSealPressure = 450.0;
        }

        part rightSleeve : SleeveAssembly {
            attribute sleeveLength = 0.64;
            attribute cuffElasticRecovery = 92.0;
            attribute wristSealPressure = 450.0;
        }

        part leftCuff : Cuff {
            attribute cuffCircumference = 0.18;
            attribute sealIntegrity = 96.0;
        }

        part rightCuff : Cuff {
            attribute cuffCircumference = 0.18;
            attribute sealIntegrity = 96.0;
        }

        part neckClosure : NeckClosure {
            attribute tieLength = 0.42;
            attribute closureIntegrity = 97.0;
        }

        part waistClosure : WaistClosure {
            attribute tieLength = 0.72;
            attribute closureIntegrity = 97.0;
        }

        part identificationLabel : Label {
            attribute protectionLevel = 3;
            attribute sizeCode = "Universal";
            attribute sterile = true;
            attribute singleUse = true;
        }

        bind wearerInterface = torsoPanel.bodyInterface;
        bind exposureInterface = torsoPanel.frontExposure;
        connect exposureInterface to frontBarrier.exterior;
        connect frontBarrier.interior to wearerInterface;
        connect leftSleeve.exteriorExposure to exposureInterface;
        connect rightSleeve.exteriorExposure to exposureInterface;
        connect leftSleeve.armInterface to wearerInterface;
        connect rightSleeve.armInterface to wearerInterface;
        connect neckClosurePort to neckClosure.closure;
        connect waistClosurePort to waistClosure.closure;

        action don {
            in item packagedGown : MedicalGownPackage;
            in item wearer : HealthcareWorker;
            out item wornGown : MedicalGown;

            first start;
            then inspectPackage;
            then insertArms;
            then secureNeck;
            then secureWaist;
            then verifyCoverage;
            then done;

            action inspectPackage;
            action insertArms;
            action secureNeck;
            action secureWaist;
            action verifyCoverage;
        }

        action protectWearer {
            in item wearer : HealthcareWorker;
            in item incomingLiquid : LiquidDroplet;
            in item incomingParticle : AirborneParticle;
            out item protectedWearer : HealthcareWorker;
            out item rejectedLiquid : LiquidDroplet;
            out item filteredParticle : AirborneParticle;

            first receiveExposure;
            then blockFluid;
            then reduceParticleTransfer;
            then maintainBodyCoverage;
            then completeProtection;

            action receiveExposure;
            action blockFluid;
            action reduceParticleTransfer;
            action maintainBodyCoverage;
            action completeProtection;
        }

        action doff {
            in item contaminatedGown : MedicalGown;
            out item waste : ClinicalWaste;

            first releaseWaistClosure;
            then releaseNeckClosure;
            then peelAwayFromBody;
            then rollContaminatedSurfaceInward;
            then discard;
            then done;

            action releaseWaistClosure;
            action releaseNeckClosure;
            action peelAwayFromBody;
            action rollContaminatedSurfaceInward;
            action discard;
        }

        state def GownUseState {
            state packaged;
            state inspected;
            state donned;
            state protecting;
            state contaminated;
            state doffed;
            state disposed;

            entry action initializePackage;
            transition first packaged;
            transition packaged to inspected accept inspectPackage;
            transition inspected to donned accept completeDonning;
            transition donned to protecting accept enterClinicalArea;
            transition protecting to contaminated accept contaminantContact;
            transition protecting to doffed accept endUse;
            transition contaminated to doffed accept controlledDoffing;
            transition doffed to disposed accept discardAsClinicalWaste;
        }
    }

    part def ClinicalUseEnvironment {
        part healthcareWorker : HealthcareWorker;
        part patient : Patient;
        part gown : MedicalGown {
            attribute protectionCoverage = 94.0;
            attribute donningTime = 45.0;
            attribute doffingTime = 60.0;
            attribute expectedUseDuration = 14400.0;
            attribute sterile = true;
            attribute reusable = false;
        }

        item liquidHazard : LiquidDroplet {
            attribute particleDiameter = 0.001;
            attribute infectiousRisk = 80.0;
            attribute impactPressure = 350.0;
        }

        item aerosolHazard : AirborneParticle {
            attribute particleDiameter = 0.000005;
            attribute infectiousRisk = 50.0;
            attribute aerosolConcentration = 1200.0;
        }

        connect gown.wearerInterface.wearer to healthcareWorker;
        connect liquidHazard to gown.exposureInterface.liquidDroplet;
        connect aerosolHazard to gown.exposureInterface.airborneParticle;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The medical gown shall provide a wearable protective barrier that covers the healthcare worker's torso and arms to reduce transfer of liquid droplets, airborne particles, and microorganisms during clinical care. */

        subject gown : MedicalGown;

        require constraint {
            gown.protectionCoverage >= 90.0
        }

        require constraint {
            gown.frontBarrier.microbialFiltrationEfficiency >= 95.0
        }

        require constraint {
            gown.frontBarrier.liquidResistance >= 80.0
        }

        require constraint {
            gown.leftCuff.sealIntegrity >= 90.0 and gown.rightCuff.sealIntegrity >= 90.0
        }
    }

    requirement def WearabilityRequirement {
        doc /* The gown shall allow the wearer to don, secure, move, and doff the garment without compromising essential body coverage. */

        subject gown : MedicalGown;

        require constraint {
            gown.donningTime <= 90.0
        }

        require constraint {
            gown.doffingTime <= 120.0
        }

        require constraint {
            gown.frontBarrier.breathableAirFlow >= 20.0
        }
    }

    requirement def DisposalRequirement {
        doc /* A single-use contaminated gown shall support controlled removal and disposal as clinical waste while keeping the contaminated exterior directed away from the wearer. */

        subject gown : MedicalGown;

        require constraint {
            gown.reusable == false
        }

        require constraint {
            gown.identificationLabel.singleUse == true
        }
    }

    satisfy PrimaryFunctionRequirement by MedicalGown;
    satisfy WearabilityRequirement by MedicalGown;
    satisfy DisposalRequirement by MedicalGown;
}