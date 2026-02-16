package 'India Mark II Hand Pump System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WaterQuality;
    attribute def MaintenanceStatus;
    
    attribute def PumpingDepth :> ISQ::LengthValue {
        doc /* Maximum depth from which water can be extracted */
    }
    
    attribute def FlowRate :> ISQ::VolumeFlowRateValue {
        doc /* Volume of water delivered per unit time */
    }
    
    attribute def StrokeRate :> ISQ::FrequencyValue {
        doc /* Number of handle strokes per minute */
    }
    
    item def GroundWater {
        attribute quality : WaterQuality;
        attribute volume : ISQ::VolumeValue;
        attribute pressure : ISQ::PressureValue;
    }
    
    port def WaterInputPort {
        in item sourceWater : GroundWater;
    }
    
    port def WaterOutputPort {
        out item deliveredWater : GroundWater;
    }
    
    port def HandlePort {
        in attribute appliedForce : ISQ::ForceValue;
        in attribute strokeCount : Real;
    }
    
    port def RodConnectionPort {
        out attribute displacement : ISQ::LengthValue;
        out attribute force : ISQ::ForceValue;
    }
    
    part def HandleAssembly {
        doc /* Lever mechanism that converts user force into vertical rod motion */
        attribute leverLength : ISQ::LengthValue;
        attribute mechanicalAdvantage : Real;
        port userInput : HandlePort;
        port rodOutput : RodConnectionPort;
    }
    
    part def PumpRod {
        doc /* Rigid connecting rod transmitting motion from handle to piston */
        attribute totalLength : ISQ::LengthValue;
        attribute diameter : ISQ::LengthValue;
        attribute material : String;
        port upperConnection : RodConnectionPort;
        port lowerConnection : RodConnectionPort;
    }
    
    part def PistonAssembly {
        doc /* Reciprocating piston with seals creating pressure differential */
        attribute pistonDiameter : ISQ::LengthValue;
        attribute strokeLength : ISQ::LengthValue;
        attribute currentPosition : ISQ::LengthValue;
        port rodConnection : RodConnectionPort;
    }
    
    part def CylinderBarrel {
        doc /* Cylindrical chamber housing the piston and water column */
        attribute innerDiameter : ISQ::LengthValue;
        attribute wallThickness : ISQ::LengthValue;
        attribute barrelLength : ISQ::LengthValue;
        port waterInlet : WaterInputPort;
        port waterOutlet : WaterOutputPort;
    }
    
    part def FootValve {
        doc /* One-way check valve preventing backflow into aquifer */
        attribute valveState : Boolean;
        attribute crackingPressure : ISQ::PressureValue;
        port inlet : WaterInputPort;
        port outlet : WaterOutputPort;
    }
    
    part def RisingMainPipe {
        doc /* Vertical pipe conveying water from cylinder to surface */
        attribute pipeLength : ISQ::LengthValue;
        attribute pipeDiameter : ISQ::LengthValue;
        port bottomPort : WaterInputPort;
        port topPort : WaterOutputPort;
    }
    
    part def DischargeSpout {
        doc /* Surface outlet for water collection */
        attribute spoutHeight : ISQ::LengthValue;
        port waterInlet : WaterInputPort;
        port waterOutlet : WaterOutputPort;
    }
    
    part def Borehole {
        doc /* Drilled well accessing groundwater aquifer */
        attribute boreholeDepth : ISQ::LengthValue;
        attribute casingDiameter : ISQ::LengthValue;
        attribute staticWaterLevel : ISQ::LengthValue;
        port aquiferAccess : WaterOutputPort;
    }
    
    action def ApplyDownstroke {
        doc /* User pushes handle down, moving piston downward */
        in handleForce : ISQ::ForceValue;
        out rodDisplacement : ISQ::LengthValue;
        out pistonPosition : ISQ::LengthValue;
    }
    
    action def CloseFootValve {
        doc /* Pressure closes foot valve, isolating cylinder from aquifer */
        out valveState : Boolean;
    }
    
    action def PressurizeWater {
        doc /* Downward piston motion pressurizes water in cylinder */
        in pistonForce : ISQ::ForceValue;
        in waterVolume : ISQ::VolumeValue;
        out waterPressure : ISQ::PressureValue;
    }
    
    action def LiftWaterColumn {
        doc /* Pressurized water rises through rising main pipe */
        in waterPressure : ISQ::PressureValue;
        in columnHeight : ISQ::LengthValue;
        out elevatedWater : GroundWater;
    }
    
    action def ApplyUpstroke {
        doc /* User pulls handle up, moving piston upward */
        in handleForce : ISQ::ForceValue;
        out rodDisplacement : ISQ::LengthValue;
        out pistonPosition : ISQ::LengthValue;
    }
    
    action def OpenFootValve {
        doc /* Suction opens foot valve, connecting cylinder to aquifer */
        out valveState : Boolean;
    }
    
    action def DrawWaterIn {
        doc /* Upward piston motion creates suction, drawing water into cylinder */
        in pistonDisplacement : ISQ::LengthValue;
        in cylinderVolume : ISQ::VolumeValue;
        out drawnWater : GroundWater;
    }
    
    action def DischargeAtSpout {
        doc /* Water exits through discharge spout for collection */
        in elevatedWater : GroundWater;
        out deliveredWater : GroundWater;
    }
    
    action def ExecutePumpCycle {
        doc /* Complete reciprocating cycle extracting and delivering water */
        first start;
        
        then action downstroke : ApplyDownstroke {
            in handleForce;
            out rodDisplacement;
            out pistonPosition;
        }
        
        then action closeValve : CloseFootValve {
            out valveState;
        }
        
        then action pressurize : PressurizeWater {
            in pistonForce;
            in waterVolume;
            out waterPressure;
        }
        
        then action liftColumn : LiftWaterColumn {
            in waterPressure = pressurize.waterPressure;
            in columnHeight;
            out elevatedWater;
        }
        
        then action upstroke : ApplyUpstroke {
            in handleForce;
            out rodDisplacement;
            out pistonPosition;
        }
        
        then action openValve : OpenFootValve {
            out valveState;
        }
        
        then action drawWater : DrawWaterIn {
            in pistonDisplacement = upstroke.rodDisplacement;
            in cylinderVolume;
            out drawnWater;
        }
        
        then action discharge : DischargeAtSpout {
            in elevatedWater = liftColumn.elevatedWater;
            out deliveredWater;
        }
        
        then done;
    }
    
    state def PumpOperationalStates {
        entry; then idle;
        
        state idle {
            doc /* Pump at rest, piston at top of stroke */
        }
        
        transition idle_to_downstroke
            first idle
            accept forceApplied
            then downstrokeActive;
        
        state downstrokeActive {
            doc /* Handle pushed down, piston descending, water pressurizing */
        }
        
        transition downstroke_to_upstroke
            first downstrokeActive
            then upstrokeActive;
        
        state upstrokeActive {
            doc /* Handle pulled up, piston ascending, water being drawn in */
        }
        
        transition upstroke_to_discharge
            first upstrokeActive
            then discharging;
        
        state discharging {
            doc /* Water flowing out of discharge spout */
        }
        
        transition discharge_to_idle
            first discharging
            then idle;
    }
    
    requirement def <'REQ-001'> DepthCapabilityRequirement {
        doc /* The pump shall extract water from depths up to 50 meters below ground surface. */
        subject pump : IndiaMarkIIPump;
        require constraint {
            pump.maximumDepth <= 50.0[m]
        }
    }
    
    requirement def <'REQ-002'> MinimumFlowRequirement {
        doc /* The pump shall deliver minimum 10 liters per minute at 25 strokes per minute from 45m depth. */
        subject pump : IndiaMarkIIPump;
        require constraint {
            pump.nominalFlowRate >= 10.0[L/min]
        }
    }
    
    requirement def <'REQ-003'> OperationalLifeRequirement {
        doc /* The pump shall operate reliably for minimum 10 years with routine maintenance. */
        subject pump : IndiaMarkIIPump;
        require constraint {
            pump.designLifetime >= 10.0[yr]
        }
    }
    
    requirement def <'REQ-004'> ManualOperationRequirement {
        doc /* The pump shall be operable by manual force without external power source. */
        subject pump : IndiaMarkIIPump;
    }
    
    requirement def <'REQ-005'> WaterSafetyRequirement {
        doc /* The pump shall not contaminate water during extraction and delivery. */
        subject pump : IndiaMarkIIPump;
    }
    
    requirement def <'REQ-006'> FieldMaintainabilityRequirement {
        doc /* The pump shall be maintainable by trained local technicians using basic hand tools. */
        subject pump : IndiaMarkIIPump;
    }
    
    part def IndiaMarkIIPump {
        doc /* 
            The India Mark II is a manually operated reciprocating piston hand pump designed 
            for extracting groundwater from deep boreholes in rural and community settings. 
            Its primary function is to lift water from depths up to 50 meters and deliver it 
            to the surface through a discharge spout by converting reciprocating manual force 
            applied to a handle into vertical piston motion within a submerged cylinder. The 
            pump uses a foot valve and piston assembly to create alternating suction and 
            pressure cycles that draw water from the aquifer and lift it through a rising 
            main pipe to a surface outlet, providing reliable access to potable groundwater 
            without requiring external power sources.
        */
        
        attribute maximumDepth : PumpingDepth;
        attribute nominalFlowRate : FlowRate;
        attribute operatingStrokeRate : StrokeRate;
        attribute designLifetime : ISQ::TimeValue;
        attribute maintenanceStatus : MaintenanceStatus;
        
        part handle : HandleAssembly {
            attribute :>> leverLength = 1.2[m];
            attribute :>> mechanicalAdvantage = 6.0;
        }
        
        part pumpRod : PumpRod {
            attribute :>> totalLength = maximumDepth;
            attribute :>> diameter = 16.0[mm];
            attribute :>> material = "Galvanized Steel";
        }
        
        part piston : PistonAssembly {
            attribute :>> pistonDiameter = 63.0[mm];
            attribute :>> strokeLength = 150.0[mm];
            attribute :>> currentPosition = 0.0[m];
        }
        
        part cylinder : CylinderBarrel {
            attribute :>> innerDiameter = 63.5[mm];
            attribute :>> wallThickness = 3.2[mm];
            attribute :>> barrelLength = 0.5[m];
        }
        
        part footValve : FootValve {
            attribute :>> valveState = false;
            attribute :>> crackingPressure = 5.0[kPa];
        }
        
        part risingMain : RisingMainPipe {
            attribute :>> pipeLength = maximumDepth;
            attribute :>> pipeDiameter = 32.0[mm];
        }
        
        part spout : DischargeSpout {
            attribute :>> spoutHeight = 0.8[m];
        }
        
        part borehole : Borehole {
            attribute :>> boreholeDepth = maximumDepth + 5.0[m];
            attribute :>> casingDiameter = 100.0[mm];
            attribute :>> staticWaterLevel = 45.0[m];
        }
        
        connection handleToRod connect handle.rodOutput to pumpRod.upperConnection;
        connection rodToPiston connect pumpRod.lowerConnection to piston.rodConnection;
        connection boreholeTofootValve connect borehole.aquiferAccess to footValve.inlet;
        connection footValveToCylinder connect footValve.outlet to cylinder.waterInlet;
        connection cylinderToRisingMain connect cylinder.waterOutlet to risingMain.bottomPort;
        connection risingMainToSpout connect risingMain.topPort to spout.waterInlet;
        
        perform action pumpingOperation : ExecutePumpCycle[*] ordered {
            doc /* Continuous pumping cycles during operation */
        }
        
        exhibit state operatingBehavior : PumpOperationalStates {
            doc /* State-based behavior of pump during operation */
        }
    }
    
    part indiaMarkIIInstance : IndiaMarkIIPump {
        doc /* Deployed instance of India Mark II pump system */
        
        attribute :>> maximumDepth = 50.0[m];
        attribute :>> nominalFlowRate = 12.0[L/min];
        attribute :>> operatingStrokeRate = 25.0[1/min];
        attribute :>> designLifetime = 10.0[yr];
        
        satisfy <'REQ-001'> by indiaMarkIIInstance;
        satisfy <'REQ-002'> by indiaMarkIIInstance;
        satisfy <'REQ-003'> by indiaMarkIIInstance;
        satisfy <'REQ-004'> by indiaMarkIIInstance;
        satisfy <'REQ-005'> by indiaMarkIIInstance;
        satisfy <'REQ-006'> by indiaMarkIIInstance;
    }
}
