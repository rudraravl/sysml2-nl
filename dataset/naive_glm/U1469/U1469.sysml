package ResidentialPlumbingSystem {
    import ScalarValues::*;
    
    item def Water;
    item def HotWater :> Water;
    item def ColdWater :> Water;
    item def Wastewater;
    
    value def Pressure { unit "Pa"; }
    value def Temperature { unit "C"; }
    value def VolumeFlowRate { unit "m3/s"; }
    value def Volume { unit "m3"; }
    
    port def WaterPort {
        out item water: Water;
        attribute pressure: Pressure;
        attribute flowRate: VolumeFlowRate;
    }
    
    port def HotWaterPort :> WaterPort {
        out item water: HotWater;
        attribute temperature: Temperature;
    }
    
    port def ColdWaterPort :> WaterPort {
        out item water: ColdWater;
        attribute temperature: Temperature;
    }
    
    port def WastewaterPort {
        in item wastewater: Wastewater;
        attribute flowRate: VolumeFlowRate;
    }
    
    connection def WaterConnection {
        end port1: WaterPort;
        end port2: WaterPort;
    }
    
    connection def WastewaterConnection {
        end port1: WastewaterPort;
        end port2: WastewaterPort;
    }
    
    part def MunicipalWaterSupply {
        out port supplyPort: WaterPort;
    }
    
    part def MunicipalSewer {
        in port sewerPort: WastewaterPort;
    }
    
    part def MainShutoffValve {
        in port inlet: WaterPort;
        out port outlet: WaterPort;
        attribute isOpen: Boolean;
    }
    
    part def PressureRegulator {
        in port inlet: WaterPort;
        out port outlet: WaterPort;
        attribute regulatedPressure: Pressure = 300000 [Pa];
    }
    
    part def WaterMeter {
        in port inlet: WaterPort;
        out port outlet: WaterPort;
        attribute totalVolume: Volume = 0 [m3];
    }
    
    part def WaterHeater {
        in port inlet: ColdWaterPort;
        out port outlet: HotWaterPort;
        attribute targetTemp: Temperature = 60 [C];
        attribute currentTemp: Temperature = 20 [C];
        
        state machine HeatingStates {
            state Idle;
            state Heating;
            
            transition first to Idle;
            transition Idle to Heating when currentTemp < targetTemp;
            transition Heating to Idle when currentTemp >= targetTemp;
        }
    }
    
    part def DistributionManifold {
        in port coldInlet: ColdWaterPort;
        in port hotInlet: HotWaterPort;
        out port coldOutlet1: ColdWaterPort;
        out port coldOutlet2: ColdWaterPort;
        out port coldOutlet3: ColdWaterPort;
        out port coldOutlet4: ColdWaterPort;
        out port hotOutlet1: HotWaterPort;
        out port hotOutlet2: HotWaterPort;
        out port hotOutlet3: HotWaterPort;
    }
    
    part def MixingValve {
        in port coldInlet: ColdWaterPort;
        in port hotInlet: HotWaterPort;
        out port outlet: WaterPort;
        attribute desiredTemp: Temperature = 40 [C];
    }
    
    part def DrainPipe {
        in port inlet: WastewaterPort;
        out port outlet: WastewaterPort;
        attribute slope: Real = 0.02;
    }
    
    part def MainDrainLine {
        in port inlet: WastewaterPort;
        out port outlet: WastewaterPort;
    }
    
    part def Fixture {
        abstract;
        in port waterInlet: WaterPort;
        out port drainOutlet: WastewaterPort;
    }
    
    part def Sink :> Fixture {
        in port coldInlet: ColdWaterPort;
        in port hotInlet: HotWaterPort;
        part mixingValve: MixingValve;
        
        connection: WaterConnection connect coldInlet to mixingValve.coldInlet;
        connection: WaterConnection connect hotInlet to mixingValve.hotInlet;
        connection: WaterConnection connect mixingValve.outlet to waterInlet;
    }
    
    part def Shower :> Fixture {
        in port coldInlet: ColdWaterPort;
        in port hotInlet: HotWaterPort;
        part mixingValve: MixingValve;
        
        connection: WaterConnection connect coldInlet to mixingValve.coldInlet;
        connection: WaterConnection connect hotInlet to mixingValve.hotInlet;
        connection: WaterConnection connect mixingValve.outlet to waterInlet;
    }
    
    part def Toilet :> Fixture {
        in port coldInlet: ColdWaterPort;
        connection: WaterConnection connect coldInlet to waterInlet;
    }
    
    part def HomePlumbingSystem {
        attribute maxPressure: Pressure = 400000 [Pa];
        attribute maxTemperature: Temperature = 50 [C];
        attribute minFlowRate: VolumeFlowRate = 0.01 [m3/s];
        
        part municipalSupply: MunicipalWaterSupply;
        part mainShutoff: MainShutoffValve;
        part pressureRegulator: PressureRegulator;
        part waterMeter: WaterMeter;
        part waterHeater: WaterHeater;
        part manifold: DistributionManifold;
        
        part kitchenSink: Sink;
        part bathroomSink: Sink;
        part shower: Shower;
        part toilet: Toilet;
        
        part kitchenDrain: DrainPipe;
        part bathroomDrain: DrainPipe;
        part showerDrain: DrainPipe;
        part toiletDrain: DrainPipe;
        
        part mainDrain: MainDrainLine;
        part municipalSewer: MunicipalSewer;
        
        connection: WaterConnection connect municipalSupply.supplyPort to mainShutoff.inlet;
        connection: WaterConnection connect mainShutoff.outlet to pressureRegulator.inlet;
        connection: WaterConnection connect pressureRegulator.outlet to waterMeter.inlet;
        connection: WaterConnection connect waterMeter.outlet to waterHeater.inlet;
        connection: WaterConnection connect waterMeter.outlet to manifold.coldInlet;
        connection: WaterConnection connect waterHeater.outlet to manifold.hotInlet;
        
        connection: WaterConnection connect manifold.coldOutlet1 to kitchenSink.coldInlet;
        connection: WaterConnection connect manifold.hotOutlet1 to kitchenSink.hotInlet;
        
        connection: WaterConnection connect manifold.coldOutlet2 to bathroomSink.coldInlet;
        connection: WaterConnection connect manifold.hotOutlet2 to bathroomSink.hotInlet;
        
        connection: WaterConnection connect manifold.coldOutlet3 to shower.coldInlet;
        connection: WaterConnection connect manifold.hotOutlet3 to shower.hotInlet;
        
        connection: WaterConnection connect manifold.coldOutlet4 to toilet.coldInlet;
        
        connection: WastewaterConnection connect kitchenSink.drainOutlet to kitchenDrain.inlet;
        connection: WastewaterConnection connect bathroomSink.drainOutlet to bathroomDrain.inlet;
        connection: WastewaterConnection connect shower.drainOutlet to showerDrain.inlet;
        connection: WastewaterConnection connect toilet.drainOutlet to toiletDrain.inlet;
        
        connection: WastewaterConnection connect kitchenDrain.outlet to mainDrain.inlet;
        connection: WastewaterConnection connect bathroomDrain.outlet to mainDrain.inlet;
        connection: WastewaterConnection connect showerDrain.outlet to mainDrain.inlet;
        connection: WastewaterConnection connect toiletDrain.outlet to mainDrain.inlet;
        
        connection: WastewaterConnection connect mainDrain.outlet to municipalSewer.sewerPort;
    }
    
    requirement def SafeOperation {
        subject system: HomePlumbingSystem;
        requirement pressureLimit {
            system.maxPressure <= 400000 [Pa]
        }
        requirement temperatureLimit {
            system.maxTemperature <= 50 [C]
        }
    }
    
    requirement def AdequateFlow {
        subject system: HomePlumbingSystem;
        requirement flowRateLimit {
            system.minFlowRate >= 0.01 [m3/s]
        }
    }
}
