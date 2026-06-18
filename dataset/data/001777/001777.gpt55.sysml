package FilterPressHighLevelDesign {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Pressure_bar :> Real {
        doc /* Gauge pressure expressed in bar. */
    }

    attribute def FlowRate_m3_per_h :> Real {
        doc /* Volumetric flow rate expressed in cubic metres per hour. */
    }

    attribute def Volume_m3 :> Real {
        doc /* Volume expressed in cubic metres. */
    }

    attribute def Mass_kg :> Real {
        doc /* Mass expressed in kilograms. */
    }

    attribute def Temperature_degC :> Real {
        doc /* Temperature expressed in degrees Celsius. */
    }

    attribute def Time_min :> Real {
        doc /* Time duration expressed in minutes. */
    }

    attribute def Percentage :> Real {
        doc /* Ratio expressed as percent. */
    }

    attribute def Turbidity_NTU :> Real {
        doc /* Filtrate clarity expressed in nephelometric turbidity units. */
    }

    attribute def ElectricalPower_kW :> Real {
        doc /* Electrical power expressed in kilowatts. */
    }

    attribute def Force_kN :> Real {
        doc /* Mechanical clamping force expressed in kilonewtons. */
    }

    attribute def Length_mm :> Real {
        doc /* Length expressed in millimetres. */
    }

    attribute def Area_m2 :> Real {
        doc /* Area expressed in square metres. */
    }

    enum def ValvePosition {
        enum open;
        enum closed;
        enum modulating;
        enum failedClosed;
        enum failedOpen;
    }

    enum def PumpMode {
        enum stopped;
        enum priming;
        enum feeding;
        enum rampingDown;
        enum faulted;
    }

    enum def PressCycleMode {
        enum idle;
        enum automatic;
        enum manual;
        enum maintenance;
        enum emergencyStop;
    }

    enum def FiltrationPhase {
        enum standby;
        enum plateClosing;
        enum slurryFilling;
        enum pressureFiltration;
        enum cakeWashing;
        enum membraneSqueezing;
        enum airBlowdown;
        enum plateOpening;
        enum cakeDischarge;
        enum clothRinsing;
        enum faultHandling;
    }

    item def Slurry {
        attribute solidsConcentration : Percentage;
        attribute density : Real;
        attribute temperature : Temperature_degC;
        attribute particleMedianSize_um : Real;
        attribute feedPressure : Pressure_bar;
        attribute volumetricFlow : FlowRate_m3_per_h;
    }

    item def Filtrate {
        attribute turbidity : Turbidity_NTU;
        attribute temperature : Temperature_degC;
        attribute residualSolids : Percentage;
        attribute dischargePressure : Pressure_bar;
        attribute volumetricFlow : FlowRate_m3_per_h;
    }

    item def FilterCake {
        attribute moistureContent : Percentage;
        attribute drySolidsMass : Mass_kg;
        attribute cakeThickness : Length_mm;
        attribute dischargeMass : Mass_kg;
    }

    item def WashWater {
        attribute temperature : Temperature_degC;
        attribute flowRate : FlowRate_m3_per_h;
        attribute pressure : Pressure_bar;
    }

    item def CompressedAir {
        attribute pressure : Pressure_bar;
        attribute flowRate : FlowRate_m3_per_h;
        attribute dewPoint_degC : Temperature_degC;
    }

    item def HydraulicOil {
        attribute pressure : Pressure_bar;
        attribute temperature : Temperature_degC;
        attribute cleanlinessClass : String;
    }

    item def ElectricalEnergy {
        attribute voltage_V : Real;
        attribute frequency_Hz : Real;
        attribute power : ElectricalPower_kW;
    }

    item def ControlSignal {
        attribute commandName : String;
        attribute commandValue : Real;
        attribute timestamp_s : Real;
    }

    item def AlarmSignal {
        attribute alarmCode : String;
        attribute severity : Integer;
        attribute active : Boolean;
    }

    item def ProcessMeasurement {
        attribute tag : String;
        attribute measuredValue : Real;
        attribute valid : Boolean;
    }

    port def SlurryInPort {
        in item slurry : Slurry;
    }

    port def FiltrateOutPort {
        out item filtrate : Filtrate;
    }

    port def CakeOutPort {
        out item cake : FilterCake;
    }

    port def WashWaterInPort {
        in item washWater : WashWater;
    }

    port def AirInPort {
        in item air : CompressedAir;
    }

    port def HydraulicPort {
        in item oilSupply : HydraulicOil;
        out item oilReturn : HydraulicOil;
    }

    port def ElectricalPowerPort {
        in item electricalEnergy : ElectricalEnergy;
    }

    port def CommandInPort {
        in item command : ControlSignal;
    }

    port def MeasurementOutPort {
        out item measurement : ProcessMeasurement;
    }

    port def AlarmOutPort {
        out item alarm : AlarmSignal;
    }

    port def ValveMaterialInPort {
        in item fluidIn : Slurry;
    }

    port def ValveMaterialOutPort {
        out item fluidOut : Slurry;
    }

    port def GenericLiquidInPort {
        in item liquidIn : Filtrate;
    }

    port def GenericLiquidOutPort {
        out item liquidOut : Filtrate;
    }

    interface def SlurryTransfer {
        end source : SlurryInPort;
        end sink : SlurryInPort;
        item slurry : Slurry;
    }

    interface def FiltrateTransfer {
        end source : FiltrateOutPort;
        end sink : GenericLiquidInPort;
        item filtrate : Filtrate;
    }

    interface def CakeTransfer {
        end source : CakeOutPort;
        end sink : CakeOutPort;
        item cake : FilterCake;
    }

    interface def WashWaterTransfer {
        end source : WashWaterInPort;
        end sink : WashWaterInPort;
        item washWater : WashWater;
    }

    interface def AirTransfer {
        end source : AirInPort;
        end sink : AirInPort;
        item air : CompressedAir;
    }

    interface def HydraulicPowerTransfer {
        end source : HydraulicPort;
        end sink : HydraulicPort;
        item oilSupply : HydraulicOil;
        item oilReturn : HydraulicOil;
    }

    interface def ElectricalPowerTransfer {
        end source : ElectricalPowerPort;
        end sink : ElectricalPowerPort;
        item electricalEnergy : ElectricalEnergy;
    }

    interface def ControlTransfer {
        end source : CommandInPort;
        end sink : CommandInPort;
        item command : ControlSignal;
    }

    part def FeedSlurryTank {
        attribute workingVolume : Volume_m3 = 12.0;
        attribute minimumOperatingVolume : Volume_m3 = 1.5;
        attribute maximumSolidsConcentration : Percentage = 45.0;
        attribute designTemperature : Temperature_degC = 60.0;

        port slurryOutlet : SlurryInPort;
        port levelMeasurement : MeasurementOutPort;
        port agitatorPower : ElectricalPowerPort;

        part agitator {
            attribute installedPower : ElectricalPower_kW = 5.5;
            attribute operatingSpeed_rpm : Real = 45.0;
        }
    }

    part def FeedPump {
        attribute ratedFlow : FlowRate_m3_per_h = 18.0;
        attribute maximumDischargePressure : Pressure_bar = 16.0;
        attribute installedPower : ElectricalPower_kW = 22.0;
        attribute mode : PumpMode = PumpMode::stopped;

        port suction : SlurryInPort;
        port discharge : SlurryInPort;
        port electricalPower : ElectricalPowerPort;
        port startStopCommand : CommandInPort;
        port pumpStatus : MeasurementOutPort;
        port pumpAlarm : AlarmOutPort;
    }

    part def FeedControlValve {
        attribute position : ValvePosition = ValvePosition::closed;
        attribute nominalDiameter_mm : Length_mm = 80.0;
        attribute maximumAllowablePressure : Pressure_bar = 16.0;

        port inlet : SlurryInPort;
        port outlet : SlurryInPort;
        port command : CommandInPort;
        port positionFeedback : MeasurementOutPort;
    }

    part def FilterPlate {
        attribute plateIndex : Integer;
        attribute filtrationArea : Area_m2 = 1.2;
        attribute chamberVolume : Volume_m3 = 0.045;
        attribute plateThickness : Length_mm = 60.0;
        attribute membraneEquipped : Boolean = true;
    }

    part def FilterCloth {
        attribute clothIndex : Integer;
        attribute poreSize_um : Real = 25.0;
        attribute maximumDifferentialPressure : Pressure_bar = 10.0;
        attribute expectedServiceCycles : Integer = 1200;
    }

    part def PlatePack {
        attribute numberOfPlates : Integer = 40;
        attribute totalFiltrationArea : Area_m2 = 48.0;
        attribute totalChamberVolume : Volume_m3 = 1.8;
        attribute closedStackLength : Length_mm = 3600.0;

        part plates[40] : FilterPlate;
        part cloths[80] : FilterCloth;

        port slurryFeedManifold : SlurryInPort;
        port filtrateManifold : FiltrateOutPort;
        port washWaterManifold : WashWaterInPort;
        port airManifold : AirInPort;
        port cakeOutlet : CakeOutPort;
    }

    part def HydraulicClosingUnit {
        attribute maximumClampingForce : Force_kN = 2800.0;
        attribute closingPressure : Pressure_bar = 180.0;
        attribute openingPressure : Pressure_bar = 120.0;
        attribute strokeLength : Length_mm = 1200.0;
        attribute oilReservoirVolume : Volume_m3 = 0.4;

        port hydraulicPower : HydraulicPort;
        port electricalPower : ElectricalPowerPort;
        port closeCommand : CommandInPort;
        port positionMeasurement : MeasurementOutPort;
        port pressureMeasurement : MeasurementOutPort;
        port alarm : AlarmOutPort;
    }

    part def FiltrateHeader {
        attribute designPressure : Pressure_bar = 10.0;
        attribute internalVolume : Volume_m3 = 0.25;

        port inletFromPlatePack : FiltrateOutPort;
        port outletToTank : FiltrateOutPort;
        port turbidityMeasurement : MeasurementOutPort;
        port pressureMeasurement : MeasurementOutPort;
    }

    part def FiltrateTank {
        attribute workingVolume : Volume_m3 = 8.0;
        attribute highLevelVolume : Volume_m3 = 7.5;
        attribute lowLevelVolume : Volume_m3 = 0.8;

        port filtrateInlet : GenericLiquidInPort;
        port filtrateOutlet : GenericLiquidOutPort;
        port levelMeasurement : MeasurementOutPort;
    }

    part def CakeDischargeSystem {
        attribute conveyorLength : Length_mm = 6500.0;
        attribute installedPower : ElectricalPower_kW = 3.0;
        attribute maximumCakeRate_kg_per_h : Real = 3500.0;

        port cakeInlet : CakeOutPort;
        port electricalPower : ElectricalPowerPort;
        port runCommand : CommandInPort;
        port dischargeMeasurement : MeasurementOutPort;
        port alarm : AlarmOutPort;
    }

    part def WashWaterSystem {
        attribute ratedFlow : FlowRate_m3_per_h = 8.0;
        attribute ratedPressure : Pressure_bar = 6.0;
        attribute tankVolume : Volume_m3 = 3.0;
        attribute pumpPower : ElectricalPower_kW = 7.5;

        port washWaterOutlet : WashWaterInPort;
        port electricalPower : ElectricalPowerPort;
        port startStopCommand : CommandInPort;
        port pressureMeasurement : MeasurementOutPort;
    }

    part def CompressedAirSystem {
        attribute supplyPressure : Pressure_bar = 7.0;
        attribute ratedFlow : FlowRate_m3_per_h = 120.0;
        attribute receiverVolume : Volume_m3 = 1.0;
        attribute dewPoint : Temperature_degC = 3.0;

        port airOutlet : AirInPort;
        port electricalPower : ElectricalPowerPort;
        port pressureMeasurement : MeasurementOutPort;
        port alarm : AlarmOutPort;
    }

    part def ControlPanel {
        attribute controllerScanTime_s : Real = 0.05;
        attribute operatingMode : PressCycleMode = PressCycleMode::idle;
        attribute recipeFeedPressure : Pressure_bar = 12.0;
        attribute recipeFiltrationTime : Time_min = 35.0;
        attribute recipeWashTime : Time_min = 8.0;
        attribute recipeSqueezeTime : Time_min = 12.0;
        attribute recipeAirBlowTime : Time_min = 5.0;

        port electricalPower : ElectricalPowerPort;
        port operatorCommand : CommandInPort;
        port feedPumpCommand : CommandInPort;
        port valveCommand : CommandInPort;
        port hydraulicCommand : CommandInPort;
        port washCommand : CommandInPort;
        port airCommand : CommandInPort;
        port conveyorCommand : CommandInPort;
        port measurementsIn : MeasurementOutPort;
        port alarmsOut : AlarmOutPort;
    }

    action def ClosePlatePack {
        in clampingPressure : Pressure_bar;
        in targetForce : Force_kN;
        out platesClosed : Boolean;

        first start;
        then applyHydraulicPressure;
        then verifyClosedPosition;
        then done;

        action applyHydraulicPressure {
            attribute commandedPressure : Pressure_bar = 180.0;
        }

        action verifyClosedPosition {
            attribute maximumPositionError : Length_mm = 5.0;
        }
    }

    action def FeedAndFilterSlurry {
        in feedPressureSetpoint : Pressure_bar;
        in feedFlowSetpoint : FlowRate_m3_per_h;
        in maximumFiltrationTime : Time_min;
        out filtrateProduced : Filtrate;
        out cakeFormed : FilterCake;

        first start;
        then startFeedPump;
        then rampToFiltrationPressure;
        then holdFiltration;
        then stopFeed;
        then done;

        action startFeedPump {
            attribute minimumSuctionVolume : Volume_m3 = 1.5;
        }

        action rampToFiltrationPressure {
            attribute rampDuration : Time_min = 4.0;
        }

        action holdFiltration {
            attribute targetPressure : Pressure_bar = 12.0;
            attribute targetFlowEndPoint : FlowRate_m3_per_h = 1.5;
        }

        action stopFeed {
            attribute pumpStopDelay_s : Real = 5.0;
        }
    }

    action def WashCake {
        in washPressure : Pressure_bar;
        in washFlow : FlowRate_m3_per_h;
        in washDuration : Time_min;
        out washedCake : FilterCake;

        first start;
        then openWashValve;
        then distributeWashWater;
        then closeWashValve;
        then done;
    }

    action def SqueezeCake {
        in membranePressure : Pressure_bar;
        in squeezeDuration : Time_min;
        out squeezedCake : FilterCake;

        first start;
        then inflateMembranes;
        then holdMembranePressure;
        then ventMembranes;
        then done;

        action holdMembranePressure {
            attribute targetMembranePressure : Pressure_bar = 8.0;
        }
    }

    action def AirBlowCakeAndCore {
        in airPressure : Pressure_bar;
        in blowDuration : Time_min;
        out dewateredCake : FilterCake;

        first start;
        then openAirValve;
        then purgeFeedCoreAndCake;
        then closeAirValve;
        then done;
    }

    action def OpenAndDischargeCake {
        in openingPressure : Pressure_bar;
        out cakeDischarged : FilterCake;

        first start;
        then retractHydraulicCylinder;
        then separatePlatesSequentially;
        then startConveyor;
        then dischargeCake;
        then stopConveyor;
        then done;
    }

    action def RinseFilterCloths {
        in rinsePressure : Pressure_bar;
        in rinseDuration : Time_min;
        out clothsReady : Boolean;

        first start;
        then sprayCloths;
        then inspectFlowBalance;
        then done;
    }

    action def ExecuteFilterPressCycle {
        in incomingSlurry : Slurry;
        out cleanFiltrate : Filtrate;
        out dewateredCake : FilterCake;

        first start;
        then closePlatePack : ClosePlatePack {
            in clampingPressure = 180.0;
            in targetForce = 2500.0;
        }
        then feedAndFilter : FeedAndFilterSlurry {
            in feedPressureSetpoint = 12.0;
            in feedFlowSetpoint = 18.0;
            in maximumFiltrationTime = 35.0;
        }
        then washCake : WashCake {
            in washPressure = 5.0;
            in washFlow = 6.0;
            in washDuration = 8.0;
        }
        then squeezeCake : SqueezeCake {
            in membranePressure = 8.0;
            in squeezeDuration = 12.0;
        }
        then airBlow : AirBlowCakeAndCore {
            in airPressure = 6.0;
            in blowDuration = 5.0;
        }
        then openAndDischarge : OpenAndDischargeCake {
            in openingPressure = 120.0;
        }
        then rinseCloths : RinseFilterCloths {
            in rinsePressure = 4.0;
            in rinseDuration = 3.0;
        }
        then done;
    }

    state def FilterPressOperatingStates {
        attribute currentPhase : FiltrationPhase = FiltrationPhase::standby;

        entry action initializeCycleData {
            attribute cycleCounterIncrement : Integer = 1;
        }

        state standby {
            entry action setSafeIdle {
                attribute feedValvePosition : ValvePosition = ValvePosition::closed;
            }
        }

        state plateClosing {
            entry action commandHydraulicClose;
            do action monitorClampForce;
        }

        state slurryFilling {
            entry action startFeedPumpAtLowSpeed;
            do action monitorFeedFlowAndPressure;
        }

        state pressureFiltration {
            do action maintainFiltrationPressure;
            exit action stopFeedPump;
        }

        state cakeWashing {
            entry action enableWashWaterPump;
            do action maintainWashFlow;
            exit action closeWashWaterPath;
        }

        state membraneSqueezing {
            entry action pressurizeMembranes;
            do action holdSqueezePressure;
            exit action ventMembraneCircuit;
        }

        state airBlowdown {
            entry action openAirBlowValve;
            do action purgeResidualLiquid;
            exit action closeAirBlowValve;
        }

        state plateOpening {
            entry action releaseClampForce;
            do action retractHydraulicCylinder;
        }

        state cakeDischarge {
            entry action startCakeConveyor;
            do action sequencePlateShifter;
            exit action stopCakeConveyor;
        }

        state clothRinsing {
            entry action startClothWash;
            do action rinseFilterCloths;
            exit action stopClothWash;
        }

        state faultHandling {
            entry action stopAllMotions;
            do action annunciateAlarm;
        }

        transition standby_to_plateClosing
            first standby
            accept ControlSignal
            if controlCommandIsAutomaticStart
            then plateClosing;

        transition plateClosing_to_slurryFilling
            first plateClosing
            if clampForceAtSetpoint
            then slurryFilling;

        transition slurryFilling_to_pressureFiltration
            first slurryFilling
            if chambersFilled
            then pressureFiltration;

        transition pressureFiltration_to_cakeWashing
            first pressureFiltration
            if filtrateFlowBelowEndpoint
            then cakeWashing;

        transition cakeWashing_to_membraneSqueezing
            first cakeWashing
            if washTimerComplete
            then membraneSqueezing;

        transition membraneSqueezing_to_airBlowdown
            first membraneSqueezing
            if squeezeTimerComplete
            then airBlowdown;

        transition airBlowdown_to_plateOpening
            first airBlowdown
            if airBlowTimerComplete
            then plateOpening;

        transition plateOpening_to_cakeDischarge
            first plateOpening
            if platesFullyOpen
            then cakeDischarge;

        transition cakeDischarge_to_clothRinsing
            first cakeDischarge
            if cakeDischargeComplete
            then clothRinsing;

        transition clothRinsing_to_standby
            first clothRinsing
            if clothRinseComplete
            then standby;

        transition any_to_faultHandling
            first standby
            accept AlarmSignal
            if criticalAlarmActive
            then faultHandling;
    }

    requirement def PrimaryFunctionRequirement {
        subject press : FilterPressSystem;
        doc /* The system shall perform pressure filtration to separate an incoming solids-liquid slurry into clarified filtrate and a dewatered filter cake. */
        require constraint {
            press.primaryFunction == "Pressure filtration separation of slurry into filtrate and filter cake"
        }
    }

    requirement def ThroughputRequirement {
        subject press : FilterPressSystem;
        doc /* The system shall process at least 12 cubic metres per hour of incoming slurry during the main filtration phase. */
        require constraint {
            press.nominalSlurryThroughput >= 12.0
        }
    }

    requirement def FiltrateClarityRequirement {
        subject press : FilterPressSystem;
        doc /* The system shall produce filtrate with turbidity not exceeding 50 NTU during steady pressure filtration. */
        require constraint {
            press.maximumFiltrateTurbidity <= 50.0
        }
    }

    requirement def CakeDrynessRequirement {
        subject press : FilterPressSystem;
        doc /* The discharged cake shall have moisture content not greater than 35 percent by mass for the specified design slurry. */
        require constraint {
            press.maximumCakeMoisture <= 35.0
        }
    }

    requirement def PressureContainmentRequirement {
        subject press : FilterPressSystem;
        doc /* Wetted pressure-retaining components shall tolerate the maximum feed pressure with a design margin. */
        require constraint {
            press.maximumAllowableFeedPressure >= 16.0
        }
    }

    requirement def HydraulicSafetyRequirement {
        subject press : FilterPressSystem;
        doc /* The hydraulic closing unit shall maintain the plate pack closed before slurry feed is enabled. */
        require constraint {
            press.minimumClampForceBeforeFeed >= 2200.0
        }
    }

    requirement def CycleTimeRequirement {
        subject press : FilterPressSystem;
        doc /* A complete automatic filtration cycle shall not exceed 75 minutes for the reference slurry recipe. */
        require constraint {
            press.maximumAutomaticCycleTime <= 75.0
        }
    }

    requirement def SafeShutdownRequirement {
        subject press : FilterPressSystem;
        doc /* The system shall stop feed, close feed isolation, vent membranes, and inhibit plate opening during an emergency stop. */
        require constraint {
            press.emergencyStopBringsSystemToSafeState == true
        }
    }

    part def FilterPressSystem {
        attribute primaryFunction : String = "Pressure filtration separation of slurry into filtrate and filter cake";
        attribute nominalSlurryThroughput : FlowRate_m3_per_h = 18.0;
        attribute maximumFiltrateTurbidity : Turbidity_NTU = 50.0;
        attribute maximumCakeMoisture : Percentage = 35.0;
        attribute maximumAllowableFeedPressure : Pressure_bar = 16.0;
        attribute minimumClampForceBeforeFeed : Force_kN = 2200.0;
        attribute maximumAutomaticCycleTime : Time_min = 75.0;
        attribute emergencyStopBringsSystemToSafeState : Boolean = true;
        attribute installedElectricalPower : ElectricalPower_kW = 45.5;
        attribute designFeedTemperature : Temperature_degC = 60.0;
        attribute automaticCycleMode : PressCycleMode = PressCycleMode::automatic;

        port slurryFeedIn : SlurryInPort;
        port filtrateOut : FiltrateOutPort;
        port cakeOut : CakeOutPort;
        port washWaterIn : WashWaterInPort;
        port compressedAirIn : AirInPort;
        port hydraulicPowerIn : HydraulicPort;
        port electricalPowerIn : ElectricalPowerPort;
        port operatorCommandIn : CommandInPort;
        port processMeasurementsOut : MeasurementOutPort;
        port alarmsOut : AlarmOutPort;

        part slurryTank : FeedSlurryTank;
        part feedPump : FeedPump;
        part feedValve : FeedControlValve;
        part platePack : PlatePack;
        part hydraulicClosingUnit : HydraulicClosingUnit;
        part filtrateHeader : FiltrateHeader;
        part filtrateTank : FiltrateTank;
        part cakeDischargeSystem : CakeDischargeSystem;
        part washWaterSystem : WashWaterSystem;
        part compressedAirSystem : CompressedAirSystem;
        part controlPanel : ControlPanel;

        perform action automaticCycle : ExecuteFilterPressCycle;

        exhibit state operatingStates : FilterPressOperatingStates;

        connection slurryTank_to_feedPump
            connect slurryTank.slurryOutlet to feedPump.suction;

        connection feedPump_to_feedValve
            connect feedPump.discharge to feedValve.inlet;

        connection feedValve_to_platePack
            connect feedValve.outlet to platePack.slurryFeedManifold;

        connection platePack_to_filtrateHeader
            connect platePack.filtrateManifold to filtrateHeader.inletFromPlatePack;

        connection filtrateHeader_to_filtrateTank
            connect filtrateHeader.outletToTank to filtrateTank.filtrateInlet;

        connection platePack_to_cakeDischarge
            connect platePack.cakeOutlet to cakeDischargeSystem.cakeInlet;

        connection washSystem_to_platePack
            connect washWaterSystem.washWaterOutlet to platePack.washWaterManifold;

        connection compressedAir_to_platePack
            connect compressedAirSystem.airOutlet to platePack.airManifold;

        connection externalSlurry_to_feedTank
            connect slurryFeedIn to slurryTank.slurryOutlet;

        connection externalFiltrateOut
            connect filtrateHeader.outletToTank to filtrateOut;

        connection externalCakeOut
            connect cakeDischargeSystem.cakeInlet to cakeOut;

        connection externalWashWater
            connect washWaterIn to washWaterSystem.washWaterOutlet;

        connection externalCompressedAir
            connect compressedAirIn to compressedAirSystem.airOutlet;

        connection externalHydraulicPower
            connect hydraulicPowerIn to hydraulicClosingUnit.hydraulicPower;

        connection externalElectricalToPump
            connect electricalPowerIn to feedPump.electricalPower;

        connection externalElectricalToHydraulic
            connect electricalPowerIn to hydraulicClosingUnit.electricalPower;

        connection externalElectricalToWash
            connect electricalPowerIn to washWaterSystem.electricalPower;

        connection externalElectricalToAir
            connect electricalPowerIn to compressedAirSystem.electricalPower;

        connection externalElectricalToConveyor
            connect electricalPowerIn to cakeDischargeSystem.electricalPower;

        connection externalElectricalToControl
            connect electricalPowerIn to controlPanel.electricalPower;

        connection operator_to_control
            connect operatorCommandIn to controlPanel.operatorCommand;

        connection control_to_feedPump
            connect controlPanel.feedPumpCommand to feedPump.startStopCommand;

        connection control_to_feedValve
            connect controlPanel.valveCommand to feedValve.command;

        connection control_to_hydraulic
            connect controlPanel.hydraulicCommand to hydraulicClosingUnit.closeCommand;

        connection control_to_wash
            connect controlPanel.washCommand to washWaterSystem.startStopCommand;

        connection control_to_conveyor
            connect controlPanel.conveyorCommand to cakeDischargeSystem.runCommand;

        connection pumpAlarm_to_systemAlarm
            connect feedPump.pumpAlarm to alarmsOut;

        connection hydraulicAlarm_to_systemAlarm
            connect hydraulicClosingUnit.alarm to alarmsOut;

        connection airAlarm_to_systemAlarm
            connect compressedAirSystem.alarm to alarmsOut;

        connection conveyorAlarm_to_systemAlarm
            connect cakeDischargeSystem.alarm to alarmsOut;

        connection filtrateMeasurement_to_systemMeasurement
            connect filtrateHeader.turbidityMeasurement to processMeasurementsOut;

        connection hydraulicMeasurement_to_systemMeasurement
            connect hydraulicClosingUnit.pressureMeasurement to processMeasurementsOut;

        connection feedValveMeasurement_to_systemMeasurement
            connect feedValve.positionFeedback to processMeasurementsOut;

        satisfy PrimaryFunctionRequirement by this;
        satisfy ThroughputRequirement by this;
        satisfy FiltrateClarityRequirement by this;
        satisfy CakeDrynessRequirement by this;
        satisfy PressureContainmentRequirement by this;
        satisfy HydraulicSafetyRequirement by this;
        satisfy CycleTimeRequirement by this;
        satisfy SafeShutdownRequirement by this;
    }

    part filterPressPlant : FilterPressSystem {
        attribute nominalSlurryThroughput = 18.0;
        attribute maximumFiltrateTurbidity = 50.0;
        attribute maximumCakeMoisture = 35.0;
        attribute maximumAllowableFeedPressure = 16.0;
        attribute minimumClampForceBeforeFeed = 2200.0;
        attribute maximumAutomaticCycleTime = 75.0;
    }

}
