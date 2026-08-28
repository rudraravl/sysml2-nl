package EndotrachealIntubationSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====

    value def PressureValue :> Real {
        unit 'mmHg';
    }

    value def VolumeValue :> Real {
        unit 'mL';
    }

    value def FlowRateValue :> Real {
        unit 'L/min';
    }

    value def ConcentrationValue :> Real {
        unit 'percent';
    }

    value def LengthValue :> Real {
        unit 'cm';
    }

    value def DiameterValue :> Real {
        unit 'mm';
    }

    value def DurationValue :> Real {
        unit 's';
    }

    value def MassValue :> Real {
        unit 'kg';
    }

    // ===== Item Types =====

    item def Oxygen {
        attribute concentration : ConcentrationValue;
        attribute flowRate : FlowRateValue;
    }

    item def Air {
        attribute volume : VolumeValue;
    }

    item def Secretions {
        attribute volume : VolumeValue;
        attribute viscosity : Real;
    }

    item def CarbonDioxide {
        attribute concentration : ConcentrationValue;
        attribute exhaled : Boolean;
    }

    item def Breath {
        attribute tidalVolume : VolumeValue;
        attribute rate : Real;
    }

    // ===== Port Definitions =====

    port def OxygenPort {
        out oxygen : Oxygen;
    }

    port def AirwayPort {
        inout air : Air;
        inout co2 : CarbonDioxide;
    }

    port def SecretionPort {
        out secretions : Secretions;
    }

    port def CuffPort {
        in pressure : PressureValue;
    }

    port def VisualizationPort {
        out view : String;
    }

    // ===== Parts: Equipment =====

    part def EndotrachealTube {
        attribute tubeDiameter : DiameterValue = 8.0;
        attribute tubeLength : LengthValue = 28.0;
        attribute cuffPressure : PressureValue;
        attribute isInserted : Boolean = false;
        attribute isCuffInflated : Boolean = false;
        attribute isSecured : Boolean = false;

        port airwayPort : AirwayPort;
        port cuffPort : CuffPort;
        port ventilationPort : AirwayPort;

        action inflateCuff(targetPressure : PressureValue) {
            assign cuffPressure = targetPressure;
            assign isCuffInflated = true;
        }

        action deflateCuff() {
            assign cuffPressure = 0;
            assign isCuffInflated = false;
        }

        action insertTube() {
            assign isInserted = true;
        }

        action removeTube() {
            assign isInserted = false;
            assign isCuffInflated = false;
            assign isSecured = false;
        }

        action secureTube() {
            assign isSecured = true;
        }
    }

    part def Laryngoscope {
        attribute bladeType : String = "Macintosh";
        attribute bladeSize : Integer = 3;
        attribute lightOn : Boolean = false;

        port visualizationPort : VisualizationPort;

        action activateLight() {
            assign lightOn = true;
        }

        action deactivateLight() {
            assign lightOn = false;
        }

        action visualizeLarynx() : String {
            return "vocal_cords_visible";
        }
    }

    part def OxygenSource {
        attribute tankCapacity : VolumeValue = 10000.0;
        attribute currentVolume : VolumeValue = 10000.0;
        attribute outputConcentration : ConcentrationValue = 100.0;
        attribute outputFlowRate : FlowRateValue = 15.0;

        port oxygenPort : OxygenPort;

        action deliverOxygen(rate : FlowRateValue) {
            assign outputFlowRate = rate;
        }

        action stopOxygen() {
            assign outputFlowRate = 0.0;
        }
    }

    part def VentilationBag {
        attribute bagVolume : VolumeValue = 1600.0;
        attribute isCompressed : Boolean = false;
        attribute connectedToOxygen : Boolean = false;
        attribute connectedToTube : Boolean = false;

        port oxygenInPort : OxygenPort;
        port patientOutPort : AirwayPort;

        action compressBag() {
            assign isCompressed = true;
        }

        action releaseBag() {
            assign isCompressed = false;
        }

        action deliverBreath(volume : VolumeValue) {
            compressBag();
            releaseBag();
        }
    }

    part def SuctionDevice {
        attribute suctionPower : PressureValue = 150.0;
        attribute canisterVolume : VolumeValue = 0.0;
        attribute isOn : Boolean = false;

        port suctionPort : SecretionPort;

        action activateSuction() {
            assign isOn = true;
        }

        action deactivateSuction() {
            assign isOn = false;
        }

        action clearSecretions(amount : VolumeValue) {
            assign canisterVolume = canisterVolume + amount;
        }
    }

    // ===== Patient =====

    part def Patient {
        attribute patientWeight : MassValue = 70.0;
        attribute oxygenSaturation : ConcentrationValue = 95.0;
        attribute respiratoryRate : Real = 12.0;
        attribute isPreoxygenated : Boolean = false;
        attribute headPositioned : Boolean = false;
        attribute vocalCordsVisible : Boolean = false;
        attribute tubePlacementConfirmed : Boolean = false;
        attribute chestRiseSymmetric : Boolean = false;
        attribute breathSoundsEqual : Boolean = false;
        attribute etco2Detected : Boolean = false;
        attribute airwayClear : Boolean = false;

        port airwayPort : AirwayPort;
        port secretionPort : SecretionPort;

        action preoxygenate(o2 : Oxygen) {
            assign oxygenSaturation = 100.0;
            assign isPreoxygenated = true;
        }

        action positionHead() {
            assign headPositioned = true;
        }

        action exposeVocalCords() {
            assign vocalCordsVisible = true;
        }

        action receiveBreath(b : Breath) {
            assign chestRiseSymmetric = true;
        }

        action exhaleCO2() {
            assign etco2Detected = true;
        }
    }

    // ===== Intubation System Assembly =====

    part def IntubationSystem {
        part endotrachealTube : EndotrachealTube;
        part laryngoscope : Laryngoscope;
        part oxygenSource : OxygenSource;
        part ventilationBag : VentilationBag;
        part suctionDevice : SuctionDevice;
        part patient : Patient;

        connection oxygenSupply connect oxygenSource.oxygenPort to ventilationBag.oxygenInPort;
        connection ventilationDelivery connect ventilationBag.patientOutPort to endotrachealTube.ventilationPort;
        connection tubeAirway connect endotrachealTube.airwayPort to patient.airwayPort;
        connection suctionInterface connect patient.secretionPort to suctionDevice.suctionPort;
    }

    // ===== State Machine for Intubation Procedure =====

    state def IntubationProcedure {
        entry action assign startTimestamp = 0.0;

        state assessingPatient {
            entry action assign patient.oxygenSaturation = patient.oxygenSaturation;
            exit action assign patient.airwayClear = true;
        }

        state preoxygenating {
            entry action oxygenSource.deliverOxygen(15.0);
            do action patient.preoxygenate(oxygenSource.oxygenPort.oxygen);
            exit action oxygenSource.stopOxygen();
        }

        state positioningHead {
            entry action patient.positionHead();
        }

        state clearingAirway {
            entry action suctionDevice.activateSuction();
            do action suctionDevice.clearSecretions(50.0);
            exit action suctionDevice.deactivateSuction();
        }

        state visualizingLarynx {
            entry action laryngoscope.activateLight();
            do action laryngoscope.visualizeLarynx();
            exit action patient.exposeVocalCords();
        }

        state insertingTube {
            entry action endotrachealTube.insertTube();
        }

        state inflatingCuff {
            entry action endotrachealTube.inflateCuff(25.0);
        }

        state confirmingPlacement {
            entry action patient.exhaleCO2();
            do action listenBreathSounds();
            do action observeChestRise();
            exit action assign patient.tubePlacementConfirmed = (patient.etco2Detected and patient.breathSoundsEqual and patient.chestRiseSymmetric);
        }

        state placementFailed {
            entry action endotrachealTube.deflateCuff();
            exit action endotrachealTube.removeTube();
        }

        state securingTube {
            entry action endotrachealTube.secureTube();
        }

        state ventilating {
            entry action ventilationBag.connectedToOxygen = true;
            entry action ventilationBag.connectedToTube = true;
            do action ventilationBag.deliverBreath(500.0);
            do action patient.receiveBreath(Breath{tidalVolume:500.0, rate:12.0});
        }

        transition assessToPreox from assessingPatient to preoxygenating;
        transition preoxToPosition from preoxygenating to positioningHead;
        transition positionToClear from positioningHead to clearingAirway;
        transition clearToVisualize from clearingAirway to visualizingLarynx;
        transition visualizeToInsert from visualizingLarynx to insertingTube;
        transition insertToInflate from insertingTube to inflatingCuff;
        transition inflateToConfirm from inflatingCuff to confirmingPlacement;
        transition confirmToFailed from confirmingPlacement to placementFailed
            when {!patient.tubePlacementConfirmed};
        transition failedToVisualize from placementFailed to visualizingLarynx;
        transition confirmToSecure from confirmingPlacement to securingTube
            when {patient.tubePlacementConfirmed};
        transition secureToVentilate from securingTube to ventilating;

        action listenBreathSounds() {
            assign patient.breathSoundsEqual = true;
        }

        action observeChestRise() {
            assign patient.chestRiseSymmetric = true;
        }
    }

    // ===== Requirements =====

    requirement def IntubationRequirement {
        doc "The system shall support safe and effective endotracheal intubation.";
    }

    requirement def EquipmentAvailabilityRequirement :> IntubationRequirement {
        doc "All necessary intubation equipment shall be available and functional.";
        subject equipment : IntubationSystem;
        require equipment.endotrachealTube.tubeDiameter >= 6.0 and equipment.endotrachealTube.tubeDiameter <= 9.0;
        require equipment.laryngoscope.lightOn == true;
        require equipment.oxygenSource.currentVolume > 0.0;
        require equipment.ventilationBag.bagVolume >= 500.0;
        require equipment.suctionDevice.suctionPower > 100.0;
    }

    requirement def CuffPressureRequirement :> IntubationRequirement {
        doc "The endotracheal tube cuff shall be inflated to a safe pressure.";
        subject tube : EndotrachealTube;
        require tube.cuffPressure >= 20.0 and tube.cuffPressure <= 30.0;
    }

    requirement def PreoxygenationRequirement :> IntubationRequirement {
        doc "The patient shall be preoxygenated with 100% oxygen before intubation.";
        subject patient : Patient;
        require patient.isPreoxygenated == true;
        require patient.oxygenSaturation >= 98.0;
    }

    requirement def PlacementConfirmationRequirement :> IntubationRequirement {
        doc "Tube placement shall be confirmed via CO2 detection, breath sounds, and chest rise.";
        subject patient : Patient;
        require patient.etco2Detected == true;
        require patient.breathSoundsEqual == true;
        require patient.chestRiseSymmetric == true;
        require patient.tubePlacementConfirmed == true;
    }

    requirement def AirwayClearanceRequirement :> IntubationRequirement {
        doc "The patient's airway shall be cleared of secretions before visualization.";
        subject patient : Patient;
        require patient.airwayClear == true;
    }

    requirement def SecureAirwayRequirement :> IntubationRequirement {
        doc "The tube shall be secured and ventilation established.";
        subject tube : EndotrachealTube;
        subject bag : VentilationBag;
        require tube.isSecured == true;
        require tube.isInserted == true;
        require tube.isCuffInflated == true;
        require bag.isCompressed == false;
    }

    // ===== Requirement Satisfaction =====

    part intubationSystem : IntubationSystem {
        satisfy EquipmentAvailabilityRequirement by equipment;
        satisfy CuffPressureRequirement by endotrachealTube;
        satisfy PreoxygenationRequirement by patient;
        satisfy PlacementConfirmationRequirement by patient;
        satisfy AirwayClearanceRequirement by patient;
        satisfy SecureAirwayRequirement by endotrachealTube, ventilationBag;
    }

    // ===== Top-level Procedure Instance =====

    action performIntubation : IntubationProcedure {
        in system : IntubationSystem;
    }
}
