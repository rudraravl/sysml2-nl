package FilterPressSystem {
    import ScalarValues::*;
    
    // ---------- Value Types with Units ----------
    attribute def Pressure {
        attribute value: Real;
        unit kPa;
    }
    
    attribute def Volume {
        attribute value: Real;
        unit m3;
    }
    
    attribute def Mass {
        attribute value: Real;
        unit kg;
    }
    
    attribute def Duration {
        attribute value: Real;
        unit min;
    }
    
    attribute def Percentage {
        attribute value: Real;
        unit percent;
    }
    
    attribute def FlowRate {
        attribute value: Real;
        unit 'm3/min';
    }
    
    attribute def Force {
        attribute value: Real;
        unit kN;
    }
    
    // ---------- Item Types ----------
    item def Slurry {
        attribute solidFraction: Percentage;
        attribute volume: Volume;
    }
    
    item def Filtrate {
        attribute clarity: Percentage;
        attribute volume: Volume;
    }
    
    item def FilterCake {
        attribute moistureContent: Percentage;
        attribute mass: Mass;
    }
    
    item def WashWater {
        attribute volume: Volume;
    }
    
    // ---------- Port Definitions ----------
    port def FluidPort {
        out item slurry: Slurry;
        in item filtrate: Filtrate;
        out item washWater: WashWater;
    }
    
    port def SlurryInPort {
        in item slurry: Slurry;
    }
    
    port def FiltrateOutPort {
        out item filtrate: Filtrate;
    }
    
    port def WashPort {
        out item washWater: WashWater;
    }
    
    port def CakeDischargePort {
        out item cake: FilterCake;
    }
    
    port def HydraulicPressurePort {
        out pressure: Pressure;
    }
    
    port def ControlSignalPort {
        out command: String;
        in feedback: String;
    }
    
    // ---------- Requirements ----------
    requirement def FiltrateClarityRequirement {
        doc "The filtrate must be at least 98% clear."
        attribute minClarity: Percentage = 98.0;
        subject filtrate: Filtrate;
        require filtrate.clarity >= minClarity;
    }
    
    requirement def CakeMoistureRequirement {
        doc "The filter cake moisture content must not exceed 30%."
        attribute maxMoisture: Percentage = 30.0;
        subject cake: FilterCake;
        require cake.moistureContent <= maxMoisture;
    }
    
    requirement def OperatingPressureRequirement {
        doc "The system must operate at pressures up to 1500 kPa."
        attribute maxPressure: Pressure = 1500.0;
        subject system: FilterPressSystem;
        require system.maxOperatingPressure <= maxPressure;
    }
    
    requirement def CycleTimeRequirement {
        doc "A full cycle must complete within 90 minutes."
        attribute maxCycleTime: Duration = 90.0;
        subject system: FilterPressSystem;
        require system.cycleTime <= maxCycleTime;
    }
    
    requirement def PlateCountRequirement {
        doc "The filter chamber must contain between 20 and 100 filter plates."
        attribute minPlates: Integer = 20;
        attribute maxPlates: Integer = 100;
        subject chamber: FilterChamber;
        require chamber.plateCount >= minPlates and chamber.plateCount <= maxPlates;
    }
    
    // ---------- Filter Media ----------
    part def FilterMedia {
        attribute porosity: Percentage = 5.0;
        attribute condition: String = "clean";
        item def TrappedSolids;
        item trappedSolids: TrappedSolids;
        
        action def FilterAction {
            in slurry: Slurry;
            out filtrate: Filtrate;
            out cake: FilterCake;
        }
    }
    
    // ---------- Filter Plate ----------
    part def FilterPlate {
        attribute plateId: Integer;
        attribute surfaceArea: Real;
        part media: FilterMedia;
        
        port filtratePort: FiltrateOutPort;
        port cakePort: CakeDischargePort;
    }
    
    // ---------- Filter Chamber ----------
    part def FilterChamber {
        attribute plateCount: Integer = 50;
        attribute maxOperatingPressure: Pressure = 1500.0;
        attribute currentPressure: Pressure;
        attribute chamberVolume: Volume;
        
        port feedPort: SlurryInPort;
        port filtratePort: FiltrateOutPort;
        port washPort: WashPort;
        port cakePort: CakeDischargePort;
        port hydraulicPort: HydraulicPressurePort;
        
        part plates: FilterPlate[20..100];
        
        attribute currentFilling: Volume;
        attribute isSealed: Boolean = false;
        
        action def FillChamber {
            in slurry: Slurry;
            attribute targetVolume: Volume;
        }
        
        action def Pressurize {
            attribute targetPressure: Pressure;
        }
        
        action def Filter {
            out filtrate: Filtrate;
            out cake: FilterCake;
        }
        
        action def Depressurize {}
        
        action def DischargeCake {
            out cake: FilterCake;
        }
        
        action def Wash {
            in washWater: WashWater;
        }
    }
    
    // ---------- Hydraulic System ----------
    part def HydraulicSystem {
        attribute clampingForce: Force;
        attribute maxPressure: Pressure = 1600.0;
        attribute currentPressure: Pressure;
        attribute isEngaged: Boolean = false;
        
        port pressurePort: HydraulicPressurePort;
        port controlPort: ControlSignalPort;
        
        action def Clamp {
            attribute targetForce: Force;
        }
        
        action def Hold {
            attribute duration: Duration;
        }
        
        action def Release {}
    }
    
    // ---------- Feed Pump ----------
    part def FeedPump {
        attribute maxFlowRate: FlowRate = 2.0;
        attribute currentFlowRate: FlowRate;
        attribute maxPressure: Pressure = 1500.0;
        attribute currentPressure: Pressure;
        attribute isRunning: Boolean = false;
        
        port inlet: SlurryInPort;
        port outlet: FluidPort;
        port controlPort: ControlSignalPort;
        
        action def Pump {
            in slurry: Slurry;
            out pumpedSlurry: Slurry;
            attribute flowRate: FlowRate;
        }
    }
    
    // ---------- Valves ----------
    part def Valve {
        attribute isOpen: Boolean = false;
        attribute position: Real = 0.0;
        
        port inlet: FluidPort;
        port outlet: FluidPort;
        port controlPort: ControlSignalPort;
        
        action def Open {}
        action def Close {}
    }
    
    // ---------- Control System ----------
    part def ControlSystem {
        attribute cycleTime: Duration = 90.0;
        attribute currentState: String = "Idle";
        attribute pressureSetpoint: Pressure = 1500.0;
        attribute holdTime: Duration = 15.0;
        
        port pumpControl: ControlSignalPort;
        port feedValveControl: ControlSignalPort;
        port filtrateValveControl: ControlSignalPort;
        port washValveControl: ControlSignalPort;
        port hydraulicControl: ControlSignalPort;
        
        state machine def FilterPressCycle {
            initial state Idle;
            
            state Closing {
                entry action { send "Close" to hydraulicControl; }
            }
            
            state Filling {
                entry action { send "Open" to feedValveControl; send "Run" to pumpControl; }
            }
            
            state Pressurizing {
                entry action { send "Pressurize" to hydraulicControl; send "Open" to filtrateValveControl; }
            }
            
            state Filtering {
                entry action { send "Hold" to hydraulicControl; }
            }
            
            state Consolidating {
                entry action { send "Hold" to hydraulicControl; }
            }
            
            state Depressurizing {
                entry action { send "Release" to hydraulicControl; send "Stop" to pumpControl; }
            }
            
            state Discharging {
                entry action { send "Open" to feedValveControl; }
            }
            
            state Washing {
                entry action { send "Open" to washValveControl; }
            }
            
            transition from Idle to Closing when controlSystem.startCommand;
            transition from Closing to Filling when hydraulicSystem.isEngaged;
            transition from Filling to Pressurizing when filterChamber.currentFilling >= filterChamber.chamberVolume;
            transition from Pressurizing to Filtering when filterChamber.currentPressure >= pressureSetpoint;
            transition from Filtering to Consolidating when filtrateFlowRate < threshold;
            transition from Consolidating to Depressurizing after holdTime;
            transition from Depressurizing to Discharging when hydraulicSystem.isEngaged == false;
            transition from Discharging to Washing when allCakesDischarged;
            transition from Washing to Idle when washComplete;
        }
        
        attribute startCommand: Boolean = false;
        attribute threshold: FlowRate = 0.05;
        attribute allCakesDischarged: Boolean = false;
        attribute washComplete: Boolean = false;
        attribute filtrateFlowRate: FlowRate;
    }
    
    // ---------- Cake Collector ----------
    part def CakeCollector {
        attribute capacity: Mass = 500.0;
        attribute currentLoad: Mass = 0.0;
        
        port inlet: CakeDischargePort;
        
        action def Collect {
            in cake: FilterCake;
        }
    }
    
    // ---------- Top-level Filter Press System ----------
    part def FilterPressSystem {
        attribute maxOperatingPressure: Pressure = 1500.0;
        attribute cycleTime: Duration = 90.0;
        attribute plateCount: Integer = 50;
        
        satisfy FiltrateClarityRequirement {
            subject filtrateRef: producedFiltrate;
        }
        
        satisfy CakeMoistureRequirement {
            subject cakeRef: producedCake;
        }
        
        satisfy OperatingPressureRequirement {
            subject systemRef: self;
        }
        
        satisfy CycleTimeRequirement {
            subject systemRef: self;
        }
        
        satisfy PlateCountRequirement {
            subject chamberRef: chamber;
        }
        
        part controlSystem: ControlSystem;
        part hydraulicSystem: HydraulicSystem;
        part chamber: FilterChamber;
        part feedPump: FeedPump;
        part feedValve: Valve;
        part filtrateValve: Valve;
        part washValve: Valve;
        part cakeCollector: CakeCollector;
        
        item producedFiltrate: Filtrate;
        item producedCake: FilterCake;
        
        connection feedPumpToFeedValve connect feedPump.outlet to feedValve.inlet;
        connection feedValveToChamber connect feedValve.outlet to chamber.feedPort;
        connection chamberFiltrateToValve connect chamber.filtratePort to filtrateValve.inlet;
        connection filtrateValveDrain connect filtrateValve.outlet to externalDrain;
        connection chamberCakeToCollector connect chamber.cakePort to cakeCollector.inlet;
        connection washValveToChamber connect washValve.outlet to chamber.washPort;
        connection hydraulicToChamber connect hydraulicSystem.pressurePort to chamber.hydraulicPort;
        
        connection controlToPump connect controlSystem.pumpControl to feedPump.controlPort;
        connection controlToFeedValve connect controlSystem.feedValveControl to feedValve.controlPort;
        connection controlToFiltrateValve connect controlSystem.filtrateValveControl to filtrateValve.controlPort;
        connection controlToWashValve connect controlSystem.washValveControl to washValve.controlPort;
        connection controlToHydraulic connect controlSystem.hydraulicControl to hydraulicSystem.controlPort;
        
        port externalDrain: FiltrateOutPort;
        port slurryIntake: SlurryInPort;
        port washIntake: WashPort;
        
        connection slurryIntakeToPump connect slurryIntake to feedPump.inlet;
        connection washIntakeToValve connect washIntake to washValve.inlet;
        
        action def ExecuteCycle {
            attribute startTime: Duration;
            attribute endTime: Duration;
            
            perform controlSystem.FilterPressCycle;
        }
    }
    
    // ---------- Instantiated System ----------
    part industrialFilterPress: FilterPressSystem {
        attribute plateCount = 50;
        attribute maxOperatingPressure = 1500.0;
        attribute cycleTime = 90.0;
        
        part chamber: FilterChamber {
            attribute plateCount = 50;
            attribute chamberVolume = 5.0;
            attribute maxOperatingPressure = 1500.0;
        }
        
        part hydraulicSystem: HydraulicSystem {
            attribute maxPressure = 1600.0;
            attribute clampingForce = 3000.0;
        }
        
        part feedPump: FeedPump {
            attribute maxFlowRate = 2.0;
            attribute maxPressure = 1500.0;
        }
        
        item producedFiltrate: Filtrate {
            attribute clarity = 98.5;
            attribute volume = 4.2;
        }
        
        item producedCake: FilterCake {
            attribute moistureContent = 28.0;
            attribute mass = 1200.0;
        }
    }
}

package FilterPressVerification {
    import FilterPressSystem::*;
    
    verification def VerifyFiltrateClarity {
        subject filtrate: Filtrate;
        objective { check filtrate.clarity >= 98.0; }
    }
    
    verification def VerifyCakeMoisture {
        subject cake: FilterCake;
        objective { check cake.moistureContent <= 30.0; }
    }
    
    verification def VerifyOperatingPressure {
        subject system: FilterPressSystem;
        objective { check system.maxOperatingPressure <= 1500.0; }
    }
    
    verification def VerifyCycleTime {
        subject system: FilterPressSystem;
        objective { check system.cycleTime <= 90.0; }
    }
    
    verification def VerifyPlateCount {
        subject chamber: FilterChamber;
        objective { check chamber.plateCount >= 20 and chamber.plateCount <= 100; }
    }
    
    part verificationSystem {
        verification verifyClarity: VerifyFiltrateClarity {
            subject = industrialFilterPress.producedFiltrate;
        }
        verification verifyMoisture: VerifyCakeMoisture {
            subject = industrialFilterPress.producedCake;
        }
        verification verifyPressure: VerifyOperatingPressure {
            subject = industrialFilterPress;
        }
        verification verifyCycle: VerifyCycleTime {
            subject = industrialFilterPress;
        }
        verification verifyPlates: VerifyPlateCount {
            subject = industrialFilterPress.chamber;
        }
    }
}
