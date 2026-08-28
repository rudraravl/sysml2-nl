package CuttingBalloonCatheterSystem {
    import ScalarValues::*;

    unit def atm;
    unit def mL;
    unit def mm;
    unit def N;
    unit def deg;

    value def Pressure :> Real { unit atm; }
    value def Volume :> Real { unit mL; }
    value def Length :> Real { unit mm; }
    value def Diameter :> Real { unit mm; }
    value def Force :> Real { unit N; }
    value def Angle :> Real { unit deg; }

    item def ContrastMedium;
    item def Guidewire;
    item def Blood;
    item def Plaque;
    item def ArterialWall;

    port def FluidPort {
        inout item fluid : ContrastMedium;
    }
    port def GuidewirePort {
        inout item wire : Guidewire;
    }

    requirement def DilateArteryRequirement {
        doc "The system shall dilate a narrowed artery by balloon inflation.";
    }
    requirement def ScorePlaqueRequirement {
        doc "The system shall create longitudinal incisions in arterial plaque using atherotomes.";
    }
    requirement def ReduceElasticRecoilRequirement {
        doc "The system shall reduce elastic recoil of the vessel after deflation.";
    }
    requirement def NavigateToLesionRequirement {
        doc "The catheter shall be navigable through the vascular system to the lesion site.";
    }
    requirement def ControlledInflationRequirement {
        doc "Inflation shall be controllable via an external inflation device with pressure monitoring.";
    }
    requirement def AtherotomeCountRequirement {
        doc "The balloon shall have three or four atherotomes mounted longitudinally.";
    }
    requirement def MaxInflationPressureRequirement {
        doc "The balloon shall not exceed its rated burst pressure during inflation.";
        attribute maxRatedPressure : Pressure = 12;
    }
    requirement def BiocompatibilityRequirement {
        doc "All patient-contacting components shall be biocompatible.";
    }
    requirement def DeflationRequirement {
        doc "The balloon shall fully deflate to allow safe withdrawal after plaque scoring.";
    }

    part def Atherotome {
        attribute bladeLength : Length = 10;
        attribute bladeWidth : Length = 0.5;
        attribute bladeHeight : Length = 0.2;
        attribute sharpnessRating : Real = 0.95;
        attribute material : String = "surgical steel";
        action def IncisePlaque {
            in target : Plaque;
            in appliedForce : Force;
            out incisionLength : Length;
            out incisionDepth : Length;
        }
        perform action incise : IncisePlaque;
    }

    part def BalloonMembrane {
        attribute nominalDiameter : Diameter = 3.0;
        attribute nominalLength : Length = 20;
        attribute burstPressure : Pressure = 18;
        attribute ratedPressure : Pressure = 12;
        attribute currentPressure : Pressure = 0;
        attribute currentDiameter : Diameter = 0;
        attribute isInflated : Boolean = false;
        attribute material : String = "nylon";
        port inflationPort : FluidPort;
        part atherotomes : Atherotome[3..4];
        action def Inflate {
            in fluid : ContrastMedium;
            in targetPressure : Pressure;
            out resultingDiameter : Diameter;
        }
        action def Deflate {
            out fluid : ContrastMedium;
            out resultingDiameter : Diameter;
        }
        perform action inflate : Inflate;
        perform action deflate : Deflate;
    }

    part def GuidewireLumen {
        attribute innerDiameter : Diameter = 0.4;
        port proximalEnd : GuidewirePort;
        port distalEnd : GuidewirePort;
        connection guidewireChannel connect proximalEnd to distalEnd;
    }

    part def InflationLumen {
        attribute innerDiameter : Diameter = 0.3;
        port proximalEnd : FluidPort;
        port distalEnd : FluidPort;
        connection fluidChannel connect proximalEnd to distalEnd;
    }

    part def CatheterShaft {
        attribute shaftLength : Length = 1500;
        attribute outerDiameter : Diameter = 1.0;
        attribute flexibility : Real = 0.8;
        attribute material : String = "polyurethane";
        part guidewireLumen : GuidewireLumen;
        part inflationLumen : InflationLumen;
    }

    part def Hub {
        port guidewireEntry : GuidewirePort;
        port inflationEntry : FluidPort;
        attribute connectorType : String = "luer lock";
    }

    part def CuttingBalloonCatheter {
        part shaft : CatheterShaft;
        part balloon : BalloonMembrane;
        part hub : Hub;
        port externalGuidewirePort : GuidewirePort;
        port externalInflationPort : FluidPort;
        connection guidewireExternalToHub connect externalGuidewirePort to hub.guidewireEntry;
        connection inflationExternalToHub connect externalInflationPort to hub.inflationEntry;
        connection guidewireHubToShaft connect hub.guidewireEntry to shaft.guidewireLumen.proximalEnd;
        connection inflationHubToShaft connect hub.inflationEntry to shaft.inflationLumen.proximalEnd;
        connection inflationShaftToBalloon connect shaft.inflationLumen.distalEnd to balloon.inflationPort;
        satisfy DilateArteryRequirement;
        satisfy ScorePlaqueRequirement;
        satisfy ReduceElasticRecoilRequirement;
        satisfy NavigateToLesionRequirement;
        satisfy AtherotomeCountRequirement;
        satisfy BiocompatibilityRequirement;
        satisfy DeflationRequirement;
    }

    part def SyringeAssembly {
        attribute volumeCapacity : Volume = 20;
        attribute currentVolume : Volume = 0;
        port fluidOutput : FluidPort;
        action def InjectFluid {
            in volume : Volume;
            out fluid : ContrastMedium;
        }
        perform action inject : InjectFluid;
    }

    part def PressureGauge {
        attribute maxReading : Pressure = 25;
        attribute currentReading : Pressure = 0;
        attribute accuracy : Real = 0.02;
        action def MeasurePressure {
            in pressure : Pressure;
            out reading : Pressure;
        }
        perform action measure : MeasurePressure;
    }

    part def InflationDevice {
        part syringe : SyringeAssembly;
        part gauge : PressureGauge;
        port catheterConnection : FluidPort;
        connection syringeToConnection connect syringe.fluidOutput to catheterConnection;
        satisfy ControlledInflationRequirement;
    }

    part def Artery {
        attribute normalDiameter : Diameter = 3.5;
        attribute currentDiameter : Diameter = 1.5;
        part wall {
            item tissue : ArterialWall;
        }
        part lesion {
            attribute stenosisPercentage : Real = 57;
            item plaque : Plaque;
        }
        item blood : Blood;
    }

    part def PatientVasculature {
        part targetArtery : Artery;
        part vascularAccessSite {
            attribute accessType : String = "femoral";
        }
    }

    state def CatheterLifecycle {
        state idle {
            doc "Catheter is prepared but not inserted into the patient.";
        }
        state navigating {
            doc "Catheter is being navigated through the vascular system over a guidewire.";
        }
        state positionedAtLesion {
            doc "Catheter balloon is positioned at the stenotic lesion under fluoroscopic guidance.";
        }
        state inflating {
            doc "Contrast medium is being slowly injected to inflate the balloon.";
        }
        state bladesEngaged {
            doc "Balloon is fully inflated and atherotomes have scored the plaque.";
        }
        state deflating {
            doc "Balloon is being deflated by withdrawing contrast medium.";
        }
        state withdrawn {
            doc "Catheter has been withdrawn from the patient.";
        }
        transition idle_to_navigating first from idle to navigating;
        transition navigating_to_positioned from navigating to positionedAtLesion;
        transition positioned_to_inflating from positionedAtLesion to inflating;
        transition inflating_to_engaged from inflating to bladesEngaged;
        transition engaged_to_deflating from bladesEngaged to deflating;
        transition deflating_to_withdrawn from deflating to withdrawn;
    }

    part def CuttingBalloonCatheterSystem {
        part catheter : CuttingBalloonCatheter;
        part inflationDevice : InflationDevice;
        part patient : PatientVasculature;
        item contrastMediumSupply : ContrastMedium;
        connection inflationDeviceToCatheter connect inflationDevice.catheterConnection to catheter.externalInflationPort;
        satisfy MaxInflationPressureRequirement;
        exhibit state lifecycle : CatheterLifecycle;

        action def PerformAngioplasty {
            in lesion : Plaque;
            in artery : Artery;
            out treatedArtery : Artery;
        }
        perform action angioplastyProcedure : PerformAngioplasty;
    }
}
