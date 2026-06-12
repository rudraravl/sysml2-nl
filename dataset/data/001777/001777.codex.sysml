package FilterPressSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure_kPa :> pressure;
    attribute def FlowRate_m3_per_h :> volumeFlowRate;
    attribute def Mass_kg :> mass;
    attribute def Volume_m3 :> volume;
    attribute def Duration_min :> time;
    attribute def Concentration_pct :> dimensionless;
    attribute def Force_kN :> force;
    attribute def Temperature_C :> temperature;

    item def Slurry {
        attribute solidsConcentration : Concentration_pct;
        attribute particleSizeMicron : Real;
        attribute temperature : Temperature_C;
        attribute volume : Volume_m3;
    }

    item def Filtrate {
        attribute residualSolidsConcentration : Concentration_pct;
        attribute volume : Volume_m3;
    }

    item def FilterCake {
        attribute retainedSolidsMass : Mass_kg;
        attribute moistureContent : Concentration_pct;
        attribute thickness_mm : Real;
    }

    item def HydraulicOil {
        attribute pressure : Pressure_kPa;
        attribute volume : Volume_m3;
    }

    item def ControlSignal {
        attribute commandCode : String;
        attribute setpointPressure : Pressure_kPa;
        attribute setpointFlow : FlowRate_m3_per_h;
    }

    item def StatusSignal {
        attribute operatingMode : String;
        attribute measuredPressure : Pressure_kPa;
        attribute measuredFlow : FlowRate_m3_per_h;
        attribute alarmActive : Boolean;
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

    port def HydraulicPort {
        inout item oil : HydraulicOil;
    }

    port def ControlPort {
        in item control : ControlSignal;
        out item status : StatusSignal;
    }

    port def DrainPort {
        out item filtrate : Filtrate;
    }

    action def ClosePlatePack {
        in clampPressureSetpoint : Pressure_kPa;
        out closed : Boolean;
    }

    action def FeedSlurry {
        in feedFlowSetpoint : FlowRate_m3_per_h;
        in feedPressureLimit : Pressure_kPa;
        out chamberFilled : Boolean;
    }

    action def SeparateLiquidFromSolids {
        in incomingSlurry : Slurry;
        out dischargedFiltrate : Filtrate;
        out accumulatedCake : FilterCake;
    }

    action def SqueezeCake {
        in squeezePressure : Pressure_kPa;
        out finalCake : FilterCake;
    }

    action def OpenPlatePack {
        out opened : Boolean;
    }

    action def DischargeCake {
        in cake : FilterCake;
        out discharged : Boolean;
    }

    state def FilterPressOperatingState {
        entry action initializeStatus;
        state Idle;
        state ClosingPlates;
        state Filling;
        state Filtering;
        state Squeezing;
        state Opening;
        state CakeDischarge;
        state Faulted;

        transition first Idle;
        transition Idle_to_Closing
            first Idle then ClosingPlates
            accept ControlSignal
            if commandCode == "START_BATCH";

        transition Closing_to_Filling
            first ClosingPlates then Filling
            if closed == true;

        transition Filling_to_Filtering
            first Filling then Filtering
            if chamberFilled == true;

        transition Filtering_to_Squeezing
            first Filtering then Squeezing
            if measuredFlow < 0.25 and measuredPressure >= 650.0;

        transition Squeezing_to_Opening
            first Squeezing then Opening
            after 10.0 [min];

        transition Opening_to_Discharge
            first Opening then CakeDischarge
            if opened == true;

        transition Discharge_to_Idle
            first CakeDischarge then Idle
            if discharged == true;

        transition Any_to_Faulted
            first Idle then Faulted
            accept StatusSignal
            if alarmActive == true;
    }

    part def FeedPump {
        port suction : SlurryInPort;
        port discharge : SlurryInPort;
        port controls : ControlPort;

        attribute ratedFlow : FlowRate_m3_per_h = 18.0;
        attribute maxDischargePressure : Pressure_kPa = 900.0;

        action pumpSlurry : FeedSlurry;
    }

    part def FilterPlate {
        port slurryFace : SlurryInPort;
        port filtrateDrain : DrainPort;

        attribute plateArea_m2 : Real = 1.2;
        attribute chamberDepth_mm : Real = 32.0;
        attribute membraneSupported : Boolean = true;
    }

    part def FilterCloth {
        port dirtySide : SlurryInPort;
        port cleanSide : DrainPort;

        attribute poreSizeMicron : Real = 8.0;
        attribute filtrationEfficiency : Concentration_pct = 99.2;
        attribute maxDifferentialPressure : Pressure_kPa = 800.0;
    }

    part def PlatePack {
        port slurryHeader : SlurryInPort;
        port filtrateHeader : FiltrateOutPort;
        port cakeOutlet : CakeOutPort;
        port hydraulicInterface : HydraulicPort;

        attribute numberOfPlates : Integer = 42;
        attribute totalFiltrationArea_m2 : Real = 50.4;
        attribute totalChamberVolume : Volume_m3 = 1.35;
        attribute clampForce : Force_kN = 2200.0;

        part plates[42] : FilterPlate;
        part cloths[84] : FilterCloth;

        action separation : SeparateLiquidFromSolids;
        action squeeze : SqueezeCake;
    }

    part def HydraulicClosingUnit {
        port hydraulicConnection : HydraulicPort;
        port controls : ControlPort;

        attribute maxOilPressure : Pressure_kPa = 16000.0;
        attribute closingForce : Force_kN = 2400.0;
        attribute closingTime : Duration_min = 2.0;

        action closePack : ClosePlatePack;
        action openPack : OpenPlatePack;
    }

    part def FiltrateManifold {
        port inlet : FiltrateOutPort;
        port outlet : FiltrateOutPort;

        attribute designFlow : FlowRate_m3_per_h = 22.0;
        attribute maxBackPressure : Pressure_kPa = 120.0;
    }

    part def CakeHandlingSystem {
        port inlet : CakeOutPort;

        attribute conveyorCapacity : Mass_kg = 2500.0;
        attribute dischargeTime : Duration_min = 6.0;

        action discharge : DischargeCake;
    }

    part def ControlPanel {
        port equipmentNetwork : ControlPort;

        attribute batchPressureLimit : Pressure_kPa = 750.0;
        attribute feedFlowSetpoint : FlowRate_m3_per_h = 14.0;
        attribute squeezePressureSetpoint : Pressure_kPa = 700.0;
        attribute automaticModeEnabled : Boolean = true;

        state machine operatingState : FilterPressOperatingState;
    }

    part def FilterPressSystem {
        doc /* Primary function: receive a pumped slurry stream, mechanically separate liquid from suspended solids by forcing filtrate through filter cloths inside a clamped plate pack, retain solids as dewatered filter cake, and discharge clarified filtrate and cake as separate outputs. */

        port slurryFeed : SlurryInPort;
        port filtrateDischarge : FiltrateOutPort;
        port cakeDischarge : CakeOutPort;
        port operatorControl : ControlPort;

        attribute nominalBatchVolume : Volume_m3 = 1.35;
        attribute nominalCycleTime : Duration_min = 55.0;
        attribute nominalFeedPressure : Pressure_kPa = 650.0;
        attribute nominalFiltrateFlow : FlowRate_m3_per_h = 12.0;
        attribute targetCakeMoisture : Concentration_pct = 32.0;
        attribute minimumSolidsCapture : Concentration_pct = 98.5;

        part feedPump : FeedPump;
        part platePack : PlatePack;
        part hydraulicUnit : HydraulicClosingUnit;
        part filtrateManifold : FiltrateManifold;
        part cakeHandler : CakeHandlingSystem;
        part controlPanel : ControlPanel;

        connection slurry_to_pump connect slurryFeed to feedPump.suction;
        connection pump_to_plate_pack connect feedPump.discharge to platePack.slurryHeader;
        connection plate_pack_to_filtrate_manifold connect platePack.filtrateHeader to filtrateManifold.inlet;
        connection filtrate_to_system_outlet connect filtrateManifold.outlet to filtrateDischarge;
        connection plate_pack_to_cake_handler connect platePack.cakeOutlet to cakeHandler.inlet;
        connection cake_handler_to_system_outlet connect cakeHandler.inlet to cakeDischarge;
        connection hydraulic_to_plate_pack connect hydraulicUnit.hydraulicConnection to platePack.hydraulicInterface;
        connection control_to_panel connect operatorControl to controlPanel.equipmentNetwork;
        connection panel_to_pump connect controlPanel.equipmentNetwork to feedPump.controls;
        connection panel_to_hydraulic connect controlPanel.equipmentNetwork to hydraulicUnit.controls;
    }

    requirement def SeparateSlurryRequirement {
        doc /* The filter press shall separate a slurry batch into clarified filtrate and dewatered filter cake by pressure filtration through filter cloths. */
        subject system : FilterPressSystem;
        require constraint {
            system.minimumSolidsCapture >= 98.5
        }
    }

    requirement def CakeMoistureRequirement {
        doc /* The filter press shall produce cake with moisture content no greater than the specified target at normal operating pressure. */
        subject system : FilterPressSystem;
        require constraint {
            system.targetCakeMoisture <= 35.0
        }
    }

    requirement def PressureContainmentRequirement {
        doc /* The plate pack and cloth assembly shall safely contain the normal filtration pressure without exceeding component differential pressure limits. */
        subject system : FilterPressSystem;
        require constraint {
            system.nominalFeedPressure <= 750.0
        }
    }

    requirement def BatchCycleRequirement {
        doc /* The filter press shall complete one close, fill, filter, squeeze, open, and cake-discharge cycle within the nominal batch cycle time. */
        subject system : FilterPressSystem;
        require constraint {
            system.nominalCycleTime <= 60.0
        }
    }

    requirement def HighLevelFunctionRequirement {
        doc /* The system shall provide the high-level function of solid-liquid separation for industrial process slurry using a mechanically clamped pressure filtration plate pack. */
        subject system : FilterPressSystem;
    }

    part filterPress : FilterPressSystem;
}