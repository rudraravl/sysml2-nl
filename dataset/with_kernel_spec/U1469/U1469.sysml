package ResidentialPlumbingSystem {
    private import ScalarValues::*;
    
    value type Pressure :> Real;
    value type Temperature :> Real;
    value type FlowRate :> Real;
    value type Volume :> Real;
    value type Slope :> Real;
    
    item def Water;
    item def Wastewater;
    
    port def WaterPort {
        out water : Water;
    }
    port def WastewaterPort {
        out wastewater : Wastewater;
    }
    
    interface def WaterConnection {
        end supplierPort : WaterPort;
        end consumerPort : ~WaterPort;
        flow of Water from supplierPort.water to consumerPort.water;
    }
    
    interface def WastewaterConnection {
        end producerPort : WastewaterPort;
        end consumerPort : ~WastewaterPort;
        flow of Wastewater from producerPort.wastewater to consumerPort.wastewater;
    }
    
    part def MunicipalSupply {
        port waterOutlet : WaterPort;
        attribute supplyPressure : Pressure;
    }
    
    part def MainShutoffValve {
        port waterInlet : ~WaterPort;
        port waterOutlet : WaterPort;
        attribute isOpen : Boolean = true;
    }
    
    part def PressureRegulator {
        port waterInlet : ~WaterPort;
        port waterOutlet : WaterPort;
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        attribute setPressure : Pressure = 60.0;
    }
    
    part def WaterMeter {
        port waterInlet : ~WaterPort;
        port waterOutlet : WaterPort;
        attribute totalVolume : Volume;
        attribute flowRate : FlowRate;
    }
    
    part def WaterHeater {
        port coldInlet : ~WaterPort;
        port hotOutlet : WaterPort;
        attribute setTemperature : Temperature = 50.0;
        attribute currentTemperature : Temperature;
        
        state {
            state idle;
            state heating;
            transition from idle to heating when currentTemperature < setTemperature;
            transition from heating to idle when currentTemperature >= setTemperature;
        }
    }
    
    part def DistributionManifold {
        port mainInletCold : ~WaterPort;
        port mainInletHot : ~WaterPort;
        port kitchenCold : WaterPort;
        port kitchenHot : WaterPort;
        port bathCold : WaterPort;
        port bathHot : WaterPort;
        port showerCold : WaterPort;
        port showerHot : WaterPort;
        port toiletCold : WaterPort;
    }
    
    part def MixingValve {
        port hotInlet : ~WaterPort;
        port coldInlet : ~WaterPort;
        port mixedOutlet : WaterPort;
        attribute mixedTemperature : Temperature;
    }
    
    part def Fixture {
        port wastewaterOutlet : WastewaterPort;
    }
    
    part def Sink :> Fixture {
        part mixingValve : MixingValve;
    }
    
    part def KitchenSink :> Sink;
    part def BathroomSink :> Sink;
    
    part def Shower :> Fixture {
        part mixingValve : MixingValve;
    }
    
    part def Toilet :> Fixture {
        port coldInlet : ~WaterPort;
    }
    
    part def DrainNetwork {
        port kitchenWaste : ~WastewaterPort;
        port bathWaste : ~WastewaterPort;
        port showerWaste : ~WastewaterPort;
        port toiletWaste : ~WastewaterPort;
        port wastewaterOutlet : WastewaterPort;
        attribute slope : Slope = 0.02;
    }
    
    part def MunicipalSewer {
        port wastewaterInlet : ~WastewaterPort;
    }
    
    part def Residence {
        part municipalSupply : MunicipalSupply;
        part mainValve : MainShutoffValve;
        part pressureRegulator : PressureRegulator;
        part waterMeter : WaterMeter;
        part waterHeater : WaterHeater;
        part distributionManifold : DistributionManifold;
        part kitchenSink : KitchenSink;
        part bathroomSink : BathroomSink;
        part shower : Shower;
        part toilet : Toilet;
        part drainNetwork : DrainNetwork;
        part municipalSewer : MunicipalSewer;
        
        interface : WaterConnection connect 
            supplierPort ::> municipalSupply.waterOutlet to 
            consumerPort ::> mainValve.waterInlet;
        interface : WaterConnection connect 
            supplierPort ::> mainValve.waterOutlet to 
            consumerPort ::> pressureRegulator.waterInlet;
        interface : WaterConnection connect 
            supplierPort ::> pressureRegulator.waterOutlet to 
            consumerPort ::> waterMeter.waterInlet;
        interface : WaterConnection connect 
            supplierPort ::> waterMeter.waterOutlet to 
            consumerPort ::> waterHeater.coldInlet;
        interface : WaterConnection connect 
            supplierPort ::> waterMeter.waterOutlet to 
            consumerPort ::> distributionManifold.mainInletCold;
        interface : WaterConnection connect 
            supplierPort ::> waterHeater.hotOutlet to 
            consumerPort ::> distributionManifold.mainInletHot;
            
        interface : WaterConnection connect 
            supplierPort ::> distributionManifold.kitchenCold to 
            consumerPort ::> kitchenSink.mixingValve.coldInlet;
        interface : WaterConnection connect 
            supplierPort ::> distributionManifold.kitchenHot to 
            consumerPort ::> kitchenSink.mixingValve.hotInlet;
        interface : WaterConnection connect 
            supplierPort ::> distributionManifold.bathCold to 
            consumerPort ::> bathroomSink.mixingValve.coldInlet;
        interface : WaterConnection connect 
            supplierPort ::> distributionManifold.bathHot to 
            consumerPort ::> bathroomSink.mixingValve.hotInlet;
        interface : WaterConnection connect 
            supplierPort ::> distributionManifold.showerCold to 
            consumerPort ::> shower.mixingValve.coldInlet;
        interface : WaterConnection connect 
            supplierPort ::> distributionManifold.showerHot to 
            consumerPort ::> shower.mixingValve.hotInlet;
        interface : WaterConnection connect 
            supplierPort ::> distributionManifold.toiletCold to 
            consumerPort ::> toilet.coldInlet;
            
        interface : WastewaterConnection connect 
            producerPort ::> kitchenSink.wastewaterOutlet to 
            consumerPort ::> drainNetwork.kitchenWaste;
        interface : WastewaterConnection connect 
            producerPort ::> bathroomSink.wastewaterOutlet to 
            consumerPort ::> drainNetwork.bathWaste;
        interface : WastewaterConnection connect 
            producerPort ::> shower.wastewaterOutlet to 
            consumerPort ::> drainNetwork.showerWaste;
        interface : WastewaterConnection connect 
            producerPort ::> toilet.wastewaterOutlet to 
            consumerPort ::> drainNetwork.toiletWaste;
            
        interface : WastewaterConnection connect 
            producerPort ::> drainNetwork.wastewaterOutlet to 
            consumerPort ::> municipalSewer.wastewaterInlet;
    }
    
    requirement def SafePressureLimit {
        subject system : Residence;
        doc /* System pressure shall not exceed 80 psi to prevent pipe damage. */
        constraint { system.pressureRegulator.outletPressure <= 80.0 }
    }
    
    requirement def SafeTemperatureLimit {
        subject system : Residence;
        doc /* Hot water delivered to fixtures shall not exceed 50 degC to prevent scalding. */
        constraint { system.waterHeater.setTemperature <= 50.0 }
    }
    
    requirement def AdequateFlowRequirement {
        subject system : Residence;
        doc /* System shall provide adequate flow to multiple fixtures simultaneously. */
        constraint { system.waterMeter.flowRate >= 7.5 }
    }
    
    requirement def GravityDrainageRequirement {
        subject system : Residence;
        doc /* Drain pipes shall have sufficient slope for gravity-fed drainage. */
        constraint { system.drainNetwork.slope >= 0.01 }
    }
    
    part residentialPlumbingSystem : Residence {
        satisfy safePressure : SafePressureLimit;
        satisfy safeTemp : SafeTemperatureLimit;
        satisfy adequateFlow : AdequateFlowRequirement;
        satisfy gravityDrain : GravityDrainageRequirement;
    }
}
