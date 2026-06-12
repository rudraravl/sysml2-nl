package MolecularAssemblerSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def LengthValue :> ISQ::length {
        unit = SI::nanometre;
    }

    attribute def TemperatureValue :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def PressureValue :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def EnergyValue :> ISQ::energy {
        unit = SI::joule;
    }

    attribute def FrequencyValue :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def AmountRateValue {
        attribute value : Real;
        attribute unitName : String = "molecule/s";
    }

    attribute def PurityValue {
        attribute value : Real;
        attribute unitName : String = "percent";
    }

    attribute def ErrorRateValue {
        attribute value : Real;
        attribute unitName : String = "defects per 1e9 placements";
    }

    item def FeedstockMolecule {
        attribute molecularFormula : String;
        attribute bindingSiteCount : Integer;
        attribute usableForAssembly : Boolean;
    }

    item def PositionedMolecule {
        attribute molecularFormula : String;
        attribute targetX : LengthValue;
        attribute targetY : LengthValue;
        attribute targetZ : LengthValue;
        attribute orientationQuaternionW : Real;
        attribute orientationQuaternionX : Real;
        attribute orientationQuaternionY : Real;
        attribute orientationQuaternionZ : Real;
        attribute placementEnergy : EnergyValue;
    }

    item def AssembledProduct {
        attribute productIdentifier : String;
        attribute atomCount : Integer;
        attribute dimensionalTolerance : LengthValue;
        attribute measuredPurity : PurityValue;
        attribute accepted : Boolean;
    }

    item def WasteStream {
        attribute contaminantCount : Integer;
        attribute rejectedMoleculeCount : Integer;
        attribute hazardClass : String;
    }

    item def AssemblyRecipe {
        attribute recipeIdentifier : String;
        attribute targetProductIdentifier : String;
        attribute requiredPlacementCount : Integer;
        attribute nominalLatticeSpacing : LengthValue;
        attribute maximumAllowedDefectRate : ErrorRateValue;
    }

    item def PlacementCommand {
        attribute commandIdentifier : String;
        attribute moleculeFormula : String;
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute dwellTime : Time;
        attribute bondingEnergy : EnergyValue;
    }

    item def SensorFrame {
        attribute frameIdentifier : String;
        attribute scanResolution : LengthValue;
        attribute stageTemperature : TemperatureValue;
        attribute chamberPressure : PressureValue;
        attribute detectedDefectCount : Integer;
    }

    item def ControlMessage {
        attribute messageIdentifier : String;
        attribute severity : String;
        attribute text : String;
    }

    port def FeedstockInPort {
        in item feedstock : FeedstockMolecule;
    }

    port def ProductOutPort {
        out item product : AssembledProduct;
    }

    port def WasteOutPort {
        out item waste : WasteStream;
    }

    port def RecipeInPort {
        in item recipe : AssemblyRecipe;
    }

    port def PlacementCommandPort {
        out item command : PlacementCommand;
    }

    port def MoleculeTransferPort {
        out item positionedMolecule : PositionedMolecule;
    }

    port def SensorDataPort {
        out item frame : SensorFrame;
    }

    port def ControlMessagePort {
        inout item message : ControlMessage;
    }

    port def ThermalPort {
        inout attribute temperature : TemperatureValue;
        inout attribute heatFlow : Power;
    }

    port def VacuumPort {
        inout attribute chamberPressure : PressureValue;
    }

    action def LoadRecipe {
        in item recipe : AssemblyRecipe;
        out attribute validRecipe : Boolean;
    }

    action def SortFeedstock {
        in item rawMolecule : FeedstockMolecule;
        out item acceptedMolecule : FeedstockMolecule;
        out item rejectedWaste : WasteStream;
    }

    action def PositionMolecule {
        in item molecule : FeedstockMolecule;
        in item command : PlacementCommand;
        out item positioned : PositionedMolecule;
    }

    action def FormBond {
        in item positioned : PositionedMolecule;
        out attribute bondFormed : Boolean;
        out attribute expendedEnergy : EnergyValue;
    }

    action def InspectAssembly {
        in item recipe : AssemblyRecipe;
        out item frame : SensorFrame;
        out attribute withinTolerance : Boolean;
    }

    action def ReleaseProduct {
        in item recipe : AssemblyRecipe;
        in attribute inspectionPassed : Boolean;
        out item product : AssembledProduct;
    }

    state def AssemblerOperatingState {
        entry action initializeControllers;
        state Idle;
        state RecipeValidation;
        state ChamberPreparation;
        state FeedstockSorting;
        state MolecularPlacement;
        state BondFormation;
        state InProcessInspection;
        state ProductRelease;
        state FaultIsolation;
        state Shutdown;

        transition first Idle;
        transition Idle_to_RecipeValidation
            first Idle
            then RecipeValidation;

        transition RecipeValidation_to_ChamberPreparation
            first RecipeValidation
            then ChamberPreparation;

        transition ChamberPreparation_to_FeedstockSorting
            first ChamberPreparation
            then FeedstockSorting;

        transition FeedstockSorting_to_MolecularPlacement
            first FeedstockSorting
            then MolecularPlacement;

        transition MolecularPlacement_to_BondFormation
            first MolecularPlacement
            then BondFormation;

        transition BondFormation_to_InProcessInspection
            first BondFormation
            then InProcessInspection;

        transition Inspection_to_Placement
            first InProcessInspection
            then MolecularPlacement;

        transition Inspection_to_ProductRelease
            first InProcessInspection
            then ProductRelease;

        transition ProductRelease_to_Idle
            first ProductRelease
            then Idle;

        transition Any_to_FaultIsolation
            first Idle
            then FaultIsolation;

        transition FaultIsolation_to_Shutdown
            first FaultIsolation
            then Shutdown;
    }

    part def FeedstockReservoir {
        port feedstockOut : FeedstockInPort;
        attribute capacity : Real;
        attribute storedMoleculeCount : Integer;
        attribute minimumPurity : PurityValue;
    }

    part def MolecularSorter {
        port unsortedFeedstock : FeedstockInPort;
        port selectedFeedstock : FeedstockInPort;
        port rejectedWaste : WasteOutPort;
        attribute sortingRate : AmountRateValue;
        attribute minimumBindingSiteConfidence : Real;
        perform action sort : SortFeedstock;
    }

    part def VacuumReactionChamber {
        port moleculeIn : FeedstockInPort;
        port productOut : ProductOutPort;
        port wasteOut : WasteOutPort;
        port vacuumInterface : VacuumPort;
        port thermalInterface : ThermalPort;
        attribute internalPressure : PressureValue;
        attribute workingVolumeX : LengthValue;
        attribute workingVolumeY : LengthValue;
        attribute workingVolumeZ : LengthValue;
        attribute contaminationLimit : Integer;
    }

    part def PositionalStage {
        port commandIn : PlacementCommandPort;
        port moleculeOut : MoleculeTransferPort;
        attribute positioningResolution : LengthValue;
        attribute maximumTravelX : LengthValue;
        attribute maximumTravelY : LengthValue;
        attribute maximumTravelZ : LengthValue;
        attribute maximumPlacementFrequency : FrequencyValue;
        perform action position : PositionMolecule;
    }

    part def ReactiveTipArray {
        port positionedMoleculeIn : MoleculeTransferPort;
        port thermalInterface : ThermalPort;
        attribute activeTipCount : Integer;
        attribute tipSpacing : LengthValue;
        attribute bondEnergyRangeMin : EnergyValue;
        attribute bondEnergyRangeMax : EnergyValue;
        attribute defectRate : ErrorRateValue;
        perform action bond : FormBond;
    }

    part def MetrologySubsystem {
        port sensorOut : SensorDataPort;
        attribute scanResolution : LengthValue;
        attribute inspectionFrameRate : FrequencyValue;
        attribute maximumDetectableDefectSize : LengthValue;
        perform action inspect : InspectAssembly;
    }

    part def ThermalControlSubsystem {
        port chamberThermal : ThermalPort;
        port tipThermal : ThermalPort;
        attribute nominalTemperature : TemperatureValue;
        attribute maximumTemperatureDeviation : TemperatureValue;
        attribute coolingCapacity : Power;
    }

    part def VacuumControlSubsystem {
        port chamberVacuum : VacuumPort;
        attribute targetPressure : PressureValue;
        attribute pumpDownTime : Time;
        attribute leakRateLimit : Real;
    }

    part def AssemblyController {
        port recipeIn : RecipeInPort;
        port placementCommandOut : PlacementCommandPort;
        port sensorDataIn : SensorDataPort;
        port controlBus : ControlMessagePort;
        attribute activeRecipeId : String;
        attribute completedPlacements : Integer;
        attribute commandedPlacementRate : AmountRateValue;
        attribute estimatedDefectRate : ErrorRateValue;
        perform action loadRecipe : LoadRecipe;
        exhibit state operatingState : AssemblerOperatingState;
    }

    part def ProductHandlingSubsystem {
        port productIn : ProductOutPort;
        port releasedProduct : ProductOutPort;
        attribute quarantineCapacity : Integer;
        attribute acceptedProductCount : Integer;
        perform action release : ReleaseProduct;
    }

    part def MolecularAssembler {
        port feedstockInput : FeedstockInPort;
        port recipeInput : RecipeInPort;
        port productOutput : ProductOutPort;
        port wasteOutput : WasteOutPort;
        port statusInterface : ControlMessagePort;

        part reservoir : FeedstockReservoir {
            attribute capacity = 1000000000.0;
            attribute storedMoleculeCount = 750000000;
        }

        part sorter : MolecularSorter {
            attribute minimumBindingSiteConfidence = 0.99999;
        }

        part chamber : VacuumReactionChamber {
            attribute contaminationLimit = 10;
        }

        part stage : PositionalStage {
            attribute positioningResolution = 0.05 [SI::nanometre];
            attribute maximumTravelX = 1000 [SI::nanometre];
            attribute maximumTravelY = 1000 [SI::nanometre];
            attribute maximumTravelZ = 250 [SI::nanometre];
        }

        part tipArray : ReactiveTipArray {
            attribute activeTipCount = 1024;
            attribute tipSpacing = 5 [SI::nanometre];
            attribute bondEnergyRangeMin = 1.0e-20 [SI::joule];
            attribute bondEnergyRangeMax = 8.0e-19 [SI::joule];
        }

        part metrology : MetrologySubsystem {
            attribute scanResolution = 0.02 [SI::nanometre];
            attribute maximumDetectableDefectSize = 0.1 [SI::nanometre];
        }

        part thermalControl : ThermalControlSubsystem {
            attribute nominalTemperature = 77 [SI::kelvin];
            attribute maximumTemperatureDeviation = 0.05 [SI::kelvin];
        }

        part vacuumControl : VacuumControlSubsystem {
            attribute targetPressure = 1.0e-9 [SI::pascal];
        }

        part controller : AssemblyController {
            attribute completedPlacements = 0;
        }

        part productHandling : ProductHandlingSubsystem {
            attribute quarantineCapacity = 100;
            attribute acceptedProductCount = 0;
        }

        connect feedstockInput to sorter.unsortedFeedstock;
        connect recipeInput to controller.recipeIn;
        connect controller.placementCommandOut to stage.commandIn;
        connect stage.moleculeOut to tipArray.positionedMoleculeIn;
        connect sorter.selectedFeedstock to chamber.moleculeIn;
        connect chamber.productOut to productHandling.productIn;
        connect productHandling.releasedProduct to productOutput;
        connect chamber.wasteOut to wasteOutput;
        connect sorter.rejectedWaste to wasteOutput;
        connect metrology.sensorOut to controller.sensorDataIn;
        connect chamber.thermalInterface to thermalControl.chamberThermal;
        connect tipArray.thermalInterface to thermalControl.tipThermal;
        connect chamber.vacuumInterface to vacuumControl.chamberVacuum;
        connect controller.controlBus to statusInterface;
    }

    requirement def PrimaryFunctionRequirement {
        subject assembler : MolecularAssembler;
        doc
        /* The molecular assembler shall construct specified nanoscale products by selecting feedstock molecules, positioning them with sub-nanometer accuracy, forming controlled chemical bonds, inspecting intermediate structure, and releasing accepted products while rejecting waste and defective assemblies. */
    }

    requirement def PlacementAccuracyRequirement {
        subject stage : PositionalStage;
        attribute requiredResolution : LengthValue = 0.1 [SI::nanometre];
        require constraint {
            stage.positioningResolution <= requiredResolution
        }
    }

    requirement def ChamberVacuumRequirement {
        subject chamber : VacuumReactionChamber;
        attribute maximumPressure : PressureValue = 1.0e-8 [SI::pascal];
        require constraint {
            chamber.internalPressure <= maximumPressure
        }
    }

    requirement def ThermalStabilityRequirement {
        subject thermalControl : ThermalControlSubsystem;
        attribute allowedDeviation : TemperatureValue = 0.1 [SI::kelvin];
        require constraint {
            thermalControl.maximumTemperatureDeviation <= allowedDeviation
        }
    }

    requirement def ProductQualityRequirement {
        subject product : AssembledProduct;
        attribute minimumPurity : Real = 99.999;
        require constraint {
            product.measuredPurity.value >= minimumPurity and product.accepted == true
        }
    }

    requirement def DefectRateRequirement {
        subject tipArray : ReactiveTipArray;
        attribute maximumDefects : Real = 1.0;
        require constraint {
            tipArray.defectRate.value <= maximumDefects
        }
    }

    requirement def InspectionResolutionRequirement {
        subject metrology : MetrologySubsystem;
        attribute requiredScanResolution : LengthValue = 0.05 [SI::nanometre];
        require constraint {
            metrology.scanResolution <= requiredScanResolution
        }
    }

    satisfy PrimaryFunctionRequirement by MolecularAssembler;
    satisfy PlacementAccuracyRequirement by PositionalStage;
    satisfy ChamberVacuumRequirement by VacuumReactionChamber;
    satisfy ThermalStabilityRequirement by ThermalControlSubsystem;
    satisfy ProductQualityRequirement by ProductHandlingSubsystem;
    satisfy DefectRateRequirement by ReactiveTipArray;
    satisfy InspectionResolutionRequirement by MetrologySubsystem;

    part molecularAssemblerSystem : MolecularAssembler;

}