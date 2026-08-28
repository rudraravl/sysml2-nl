package MillerAbbottTubeSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    attribute def PressureValue :> Real { unit 'Pa'; }
    attribute def VolumeValue :> Real { unit 'm3'; }
    attribute def LengthValue :> Real { unit 'm'; }
    attribute def MassValue :> Real { unit 'kg'; }
    attribute def FlowRateValue :> Real { unit 'm3/s'; }
    attribute def DurationValue :> Real { unit 's'; }

    // ===== Item Types =====
    item def Gas;
    item def Fluid;
    item def IntestinalContent :> PhysicalThing {
        attribute gasFraction : Real;
        attribute fluidFraction : Real;
    }
    item def Mercury;
    item def Air;
    item def SalineSolution;

    // ===== Enumerations =====
    enum def TubePosition {
        nasoGastric,
        stomach,
        duodenum,
        jejunum,
        nearObstruction,
        removed
    }

    enum def BalloonState {
        deflated,
        inflating,
        inflated,
        deflating
    }

    enum def SuctionState {
        off,
        active,
        paused
    }

    enum def DecompressionStatus {
        notStarted,
        inProgress,
        effective,
        ineffective,
        complete
    }

    // ===== Port Definitions =====
    port def SuctionPort {
        attribute pressure : PressureValue;
        out item contents : IntestinalContent;
    }

    port def BalloonPort {
        attribute balloonState : BalloonState;
        in item inflationMedium : Air;
    }

    port def TubePositionPort {
        attribute position : TubePosition;
        attribute insertionDepth : LengthValue;
    }

    port def PatientInterfacePort {
        out item peristalticForce : Real;
        out item obstructionPresent : Boolean;
        out item bowelDistension : Real;
    }

    // ===== Requirements =====
    requirement def DecompressionRequirement {
        doc { /* The system must relieve small bowel obstruction by removing trapped gas and fluid. */ }
        attribute targetPressureReduction : PressureValue = 2000.0;
        attribute maxSuctionPressure : PressureValue = 5000.0;
        subject system : MillerAbbottTubeSystem;
        require constraint { system.suctionApparatus.vacuumPressure <= maxSuctionPressure }
        require constraint { system.decompressionStatus == DecompressionStatus::effective }
    }

    requirement def TubeAdvancementRequirement {
        doc { /* The tube must be advanced to the obstruction using peristalsis. */ }
        attribute maxInsertionTime : DurationValue = 3600.0;
        subject tube : MillerAbbottTube;
        require constraint { tube.position == TubePosition::nearObstruction }
    }

    requirement def BalloonInflationRequirement {
        doc { /* The distal balloon must be inflated to enable peristaltic advancement. */ }
        attribute targetVolume : VolumeValue = 0.00003;
        attribute maxVolume : VolumeValue = 0.00005;
        subject balloon : DistalBalloon;
        require constraint { balloon.inflatedVolume >= targetVolume }
        require constraint { balloon.inflatedVolume <= maxVolume }
    }

    // ===== Parts =====
    part def MillerAbbottTubeSystem {
        port suctionControlPort : SuctionPort;
        port balloonControlPort : BalloonPort;
        port positionMonitorPort : TubePositionPort;
        port patientInterfacePort : PatientInterfacePort;

        attribute decompressionStatus : DecompressionStatus = DecompressionStatus::notStarted;

        part millerAbbottTube : MillerAbbottTube {
            port proximalEnd : SuctionPort;
            port balloonInflationPort : BalloonPort;
            port positionPort : TubePositionPort;
        }

        part suctionApparatus : SuctionApparatus {
            port suctionConnection : SuctionPort;
            port vacuumControl : SuctionPort;
        }

        part patientSmallIntestine : SmallIntestine {
            port lumenInterface : PatientInterfacePort;
            port obstructionSite : PatientInterfacePort;
        }

        connection def SuctionLine {
            end source : SuctionPort;
            end target : SuctionPort;
        }

        connection suctionLine : SuctionLine connect millerAbbottTube.proximalEnd to suctionApparatus.suctionConnection;

        connection balloonLine : BalloonPort connect millerAbbottTube.balloonInflationPort to balloonControlPort;

        connection positionFeedback : TubePositionPort connect millerAbbottTube.positionPort to positionMonitorPort;

        connection patientContact : PatientInterfacePort connect patientSmallIntestine.lumenInterface to patientInterfacePort;

        // System-level behavior
        behavior decompressionProcedure : DecompressionProcedure {
            // defined below
        }

        satisfy DecompressionRequirement by decompressionProcedure;
    }

    part def MillerAbbottTube {
        attribute tubeLength : LengthValue = 3.0;
        attribute tubeDiameter : LengthValue = 0.006;
        attribute position : TubePosition = TubePosition::nasoGastric;
        attribute insertionDepth : LengthValue = 0.0;

        port proximalEnd : SuctionPort;
        port balloonInflationPort : BalloonPort;
        port positionPort : TubePositionPort;

        part aspirationLumen : AspirationLumen {
            port distalSuctionHoles : SuctionPort;
            port proximalConnector : SuctionPort;
            attribute lumenDiameter : LengthValue = 0.003;
            attribute numberOfHoles : Integer = 8;
        }

        part balloonLumen : BalloonLumen {
            port proximalInflationPort : BalloonPort;
            port distalBalloonPort : BalloonPort;
            attribute lumenDiameter : LengthValue = 0.0015;
        }

        part distalBalloon : DistalBalloon {
            port inflationPort : BalloonPort;
            attribute inflatedVolume : VolumeValue = 0.0;
            attribute maxVolume : VolumeValue = 0.00005;
            attribute balloonState : BalloonState = BalloonState::deflated;
        }

        part mercuryWeightedTip : MercuryWeightedTip {
            attribute mercuryMass : MassValue = 0.002;
            part mercuryFill : Mercury;
        }

        part tubeBody : TubeBody {
            attribute material : String = "rubber";
            attribute flexibility : Real = 0.8;
        }

        connection aspirationChannel : SuctionPort connect aspirationLumen.proximalConnector to proximalEnd;
        connection balloonChannel : BalloonPort connect balloonLumen.proximalInflationPort to balloonInflationPort;
        connection balloonDelivery : BalloonPort connect balloonLumen.distalBalloonPort to distalBalloon.inflationPort;

        behavior advancementStateMachine : TubeAdvancementStateMachine {
            // defined below
        }

        satisfy TubeAdvancementRequirement by advancementStateMachine;
    }

    part def AspirationLumen {
        attribute lumenDiameter : LengthValue;
        attribute numberOfHoles : Integer;
        port distalSuctionHoles : SuctionPort;
        port proximalConnector : SuctionPort;

        action def AspirateContents {
            in item intestinalContents : IntestinalContent;
            out item aspiratedContents : IntestinalContent;
            attribute flowRate : FlowRateValue = 0.000001;
        }

        behavior aspirationAction : AspirateContents;
    }

    part def BalloonLumen {
        attribute lumenDiameter : LengthValue;
        port proximalInflationPort : BalloonPort;
        port distalBalloonPort : BalloonPort;
    }

    part def DistalBalloon {
        attribute inflatedVolume : VolumeValue;
        attribute maxVolume : VolumeValue;
        attribute balloonState : BalloonState;
        port inflationPort : BalloonPort;

        action def InflateBalloon {
            in item inflationMedium : Air;
            attribute targetVolume : VolumeValue = 0.00003;
            then attribute balloonState : BalloonState = BalloonState::inflated;
        }

        action def DeflateBalloon {
            out item expelledAir : Air;
            then attribute balloonState : BalloonState = BalloonState::deflated;
        }

        satisfy BalloonInflationRequirement by InflateBalloon;
    }

    part def MercuryWeightedTip {
        attribute mercuryMass : MassValue;
        part mercuryFill : Mercury;
    }

    part def TubeBody {
        attribute material : String;
        attribute flexibility : Real;
    }

    part def SuctionApparatus {
        attribute vacuumPressure : PressureValue = 3000.0;
        attribute suctionState : SuctionState = SuctionState::off;
        attribute flowRate : FlowRateValue = 0.000001;
        attribute collectionContainerVolume : VolumeValue = 0.001;

        port suctionConnection : SuctionPort;
        port vacuumControl : SuctionPort;

        part collectionContainer : CollectionContainer {
            attribute capacity : VolumeValue = 0.002;
            attribute currentVolume : VolumeValue = 0.0;
            port inlet : SuctionPort;
        }

        part vacuumPump : VacuumPump {
            attribute generatedVacuum : PressureValue = 3000.0;
            port output : SuctionPort;
        }

        connection vacuumLine : SuctionPort connect vacuumPump.output to collectionContainer.inlet;

        action def ActivateSuction {
            in attribute targetPressure : PressureValue;
            then attribute suctionState : SuctionState = SuctionState::active;
        }

        action def DeactivateSuction {
            then attribute suctionState : SuctionState = SuctionState::off;
        }

        behavior suctionControl : ActivateSuction;
    }

    part def CollectionContainer {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        port inlet : SuctionPort;
    }

    part def VacuumPump {
        attribute generatedVacuum : PressureValue;
        port output : SuctionPort;
    }

    part def SmallIntestine {
        attribute obstructionPresent : Boolean = true;
        attribute bowelDistension : Real = 0.7;
        attribute peristalsisActive : Boolean = true;
        attribute peristalticForce : Real = 0.5;

        port lumenInterface : PatientInterfacePort;
        port obstructionSite : PatientInterfacePort;

        part intestinalWall : IntestinalWall {
            attribute elasticity : Real = 0.6;
            attribute wallThickness : LengthValue = 0.003;
        }

        part obstructedSegment : ObstructedSegment {
            attribute location : LengthValue = 1.5;
            attribute severity : Real = 0.8;
            port obstructionInterface : PatientInterfacePort;
        }

        part proximalSegment : IntestinalSegment {
            attribute gasVolume : VolumeValue = 0.0005;
            attribute fluidVolume : VolumeValue = 0.0003;
            attribute distension : Real = 0.7;
            port segmentInterface : PatientInterfacePort;
        }

        part distalSegment : IntestinalSegment {
            attribute gasVolume : VolumeValue = 0.0001;
            attribute fluidVolume : VolumeValue = 0.00005;
            attribute distension : Real = 0.1;
            port segmentInterface : PatientInterfacePort;
        }

        behavior peristalsisStateMachine : PeristalsisStateMachine;

        connection proximalToObstruction : PatientInterfacePort connect proximalSegment.segmentInterface to obstructedSegment.obstructionInterface;
    }

    part def IntestinalWall {
        attribute elasticity : Real;
        attribute wallThickness : LengthValue;
    }

    part def ObstructedSegment {
        attribute location : LengthValue;
        attribute severity : Real;
        port obstructionInterface : PatientInterfacePort;
    }

    part def IntestinalSegment {
        attribute gasVolume : VolumeValue;
        attribute fluidVolume : VolumeValue;
        attribute distension : Real;
        port segmentInterface : PatientInterfacePort;
    }

    // ===== Behaviors =====
    behavior def TubeAdvancementStateMachine {
        state InsertionPhase {
            entry attribute position : TubePosition = TubePosition::nasoGastric;
            then attribute position : TubePosition = TubePosition::stomach;
        }

        state AdvancementPhase {
            entry attribute position : TubePosition = TubePosition::duodenum;
            do attribute position : TubePosition = TubePosition::jejunum;
            then attribute position : TubePosition = TubePosition::nearObstruction;
        }

        state PositionedAtObstruction {
            entry attribute balloonState : BalloonState = BalloonState::inflated;
        }

        state RemovalPhase {
            entry attribute balloonState : BalloonState = BalloonState::deflated;
            then attribute position : TubePosition = TubePosition::removed;
        }

        transition InsertionPhase -> AdvancementPhase
            when (position == TubePosition::stomach) {
                attribute balloonState : BalloonState = BalloonState::inflating;
        }

        transition AdvancementPhase -> PositionedAtObstruction
            when (position == TubePosition::nearObstruction);

        transition PositionedAtObstruction -> RemovalPhase
            when (decompressionStatus == DecompressionStatus::complete);
    }

    behavior def PeristalsisStateMachine {
        state Resting {
            attribute peristalsisActive : Boolean = false;
        }

        state Contracting {
            attribute peristalsisActive : Boolean = true;
            attribute peristalticForce : Real = 0.5;
            do attribute peristalticForce : Real = 0.8;
        }

        state Relaxing {
            attribute peristalsisActive : Boolean = true;
            attribute peristalticForce : Real = 0.3;
        }

        transition Resting -> Contracting
            when (bowelDistension > 0.3);

        transition Contracting -> Relaxing
            when (peristalticForce >= 0.8);

        transition Relaxing -> Resting
            when (peristalticForce <= 0.3);
    }

    behavior def DecompressionProcedure {
        action InsertTube {
            doc { /* Insert tube through nose and advance into small intestine. */ }
            in attribute insertionPath : String = "naso-gastric";
            out attribute tubePosition : TubePosition = TubePosition::stomach;
        }

        action AdvanceToObstruction {
            doc { /* Peristalsis grips inflated balloon and propels tube to obstruction. */ }
            in attribute balloonInflated : Boolean;
            in attribute peristalsisActive : Boolean;
            out attribute tubePosition : TubePosition = TubePosition::nearObstruction;
        }

        action InflateDistalBalloon {
            doc { /* Inflate the distal balloon to enable peristaltic grip. */ }
            in item inflationMedium : Air;
            out attribute balloonState : BalloonState = BalloonState::inflated;
        }

        action ActivateSuctionApparatus {
            doc { /* Activate suction to aspirate trapped gas and fluid. */ }
            in attribute targetVacuum : PressureValue = 3000.0;
            out attribute suctionState : SuctionState = SuctionState::active;
        }

        action MonitorDecompression {
            doc { /* Monitor tube position and decompression effectiveness. */ }
            in attribute tubePosition : TubePosition;
            in attribute suctionState : SuctionState;
            out attribute decompressionStatus : DecompressionStatus;
        }

        action DeflateBalloonAndRemove {
            doc { /* Deflate balloon and remove tube. */ }
            in attribute decompressionStatus : DecompressionStatus;
            out attribute balloonState : BalloonState = BalloonState::deflated;
            out attribute tubePosition : TubePosition = TubePosition::removed;
        }

        flow InsertTube.tubePosition -> AdvanceToObstruction.tubePosition;
        flow InflateDistalBalloon.balloonState -> AdvanceToObstruction.balloonInflated;
        flow AdvanceToObstruction.tubePosition -> ActivateSuctionApparatus;
        flow ActivateSuctionApparatus.suctionState -> MonitorDecompression.suctionState;
        flow MonitorDecompression.decompressionStatus -> DeflateBalloonAndRemove.decompressionStatus;

        then DecompressionStatus::complete;
    }

    // ===== Allocations =====
    allocation def ProcedureAllocation {
        allocation DecompressionProcedure.InsertTube to MillerAbbottTube.tubeBody;
        allocation DecompressionProcedure.AdvanceToObstruction to SmallIntestine.proximalSegment;
        allocation DecompressionProcedure.InflateDistalBalloon to DistalBalloon.InflateBalloon;
        allocation DecompressionProcedure.ActivateSuctionApparatus to SuctionApparatus.ActivateSuction;
        allocation DecompressionProcedure.MonitorDecompression to MillerAbbottTubeSystem;
        allocation DecompressionProcedure.DeflateBalloonAndRemove to DistalBalloon.DeflateBalloon;
    }
}
