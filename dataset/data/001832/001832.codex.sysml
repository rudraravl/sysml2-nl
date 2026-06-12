package PlumbingSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :> scalar;
        unit = "kPa";
    }

    attribute def FlowRate {
        :> scalar;
        unit = "L/min";
    }

    attribute def Volume {
        :> scalar;
        unit = "L";
    }

    attribute def Temperature {
        :> scalar;
        unit = "degC";
    }

    attribute def PipeDiameter {
        :> scalar;
        unit = "mm";
    }

    attribute def Length {
        :> scalar;
        unit = "m";
    }

    attribute def WaterQualityIndex {
        :> scalar;
        unit = "1";
    }

    item def PotableWater {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute quality : WaterQualityIndex;
    }

    item def WasteWater {
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
        attribute contaminantLoad : WaterQualityIndex;
    }

    item def VentAir {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def WaterInletPort {
        in item water : PotableWater;
    }

    port def WaterOutletPort {
        out item water : PotableWater;
    }

    port def WasteInletPort {
        in item waste : WasteWater;
    }

    port def WasteOutletPort {
        out item waste : WasteWater;
    }

    port def VentPort {
        inout item air : VentAir;
    }

    port def ControlPort {
        in attribute commandOpen : Boolean;
        out attribute valveOpen : Boolean;
        out attribute faultDetected : Boolean;
    }

    part def PipeSegment {
        attribute length : Length;
        attribute insideDiameter : PipeDiameter;
        attribute ratedPressure : Pressure;
        attribute currentPressure : Pressure;
        attribute currentFlow : FlowRate;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
    }

    part def DrainPipeSegment {
        attribute length : Length;
        attribute insideDiameter : PipeDiameter;
        attribute slope : Real;
        attribute currentWasteFlow : FlowRate;

        port inlet : WasteInletPort;
        port outlet : WasteOutletPort;
        port vent : VentPort;
    }

    part def ShutoffValve {
        attribute open : Boolean;
        attribute ratedPressure : Pressure;
        attribute commandedOpen : Boolean;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        port control : ControlPort;

        state def ValveStateMachine {
            state closed;
            state opening;
            state openState;
            state closing;
            state failed;

            entry action initialize {
                open = false;
            }

            transition first closed;
            transition closed_to_opening
                first closed
                then opening
                accept commandOpen
                if commandedOpen == true;

            transition opening_to_open
                first opening
                then openState
                do {
                    open = true;
                }

            transition open_to_closing
                first openState
                then closing
                accept commandOpen
                if commandedOpen == false;

            transition closing_to_closed
                first closing
                then closed
                do {
                    open = false;
                }

            transition pressure_fault
                first openState
                then failed
                if ratedPressure < inlet.water.pressure;
        }

        behavior valveBehavior : ValveStateMachine;
    }

    part def PressureRegulator {
        attribute targetOutletPressure : Pressure;
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        attribute maximumFlow : FlowRate;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;

        action regulatePressure {
            in item incoming : PotableWater;
            out item regulated : PotableWater;
            regulated.pressure = targetOutletPressure;
            regulated.temperature = incoming.temperature;
            regulated.quality = incoming.quality;
            regulated.flowRate = incoming.flowRate;
        }
    }

    part def WaterHeater {
        attribute tankCapacity : Volume;
        attribute setpointTemperature : Temperature;
        attribute currentTemperature : Temperature;
        attribute maximumPressure : Pressure;
        attribute heatingEnabled : Boolean;

        port coldInlet : WaterInletPort;
        port hotOutlet : WaterOutletPort;

        action heatWater {
            in item coldWater : PotableWater;
            out item hotWater : PotableWater;
            hotWater.temperature = setpointTemperature;
            hotWater.pressure = coldWater.pressure;
            hotWater.flowRate = coldWater.flowRate;
            hotWater.quality = coldWater.quality;
        }

        state def HeaterStateMachine {
            state standby;
            state heating;
            state ready;
            state overpressureLockout;

            transition first standby;

            transition standby_to_heating
                first standby
                then heating
                if currentTemperature < setpointTemperature;

            transition heating_to_ready
                first heating
                then ready
                do {
                    heatingEnabled = false;
                    currentTemperature = setpointTemperature;
                }

            transition ready_to_heating
                first ready
                then heating
                if currentTemperature < setpointTemperature - 5.0;

            transition any_to_lockout
                first heating
                then overpressureLockout
                if hotOutlet.water.pressure > maximumPressure;
        }

        behavior heaterBehavior : HeaterStateMachine;
    }

    part def Fixture {
        attribute fixtureName : String;
        attribute requiredFlow : FlowRate;
        attribute minimumPressure : Pressure;
        attribute hotWaterDemand : FlowRate;
        attribute coldWaterDemand : FlowRate;

        port coldSupply : WaterInletPort;
        port hotSupply : WaterInletPort;
        port drainOutlet : WasteOutletPort;

        action deliverWater {
            in item cold : PotableWater;
            in item hot : PotableWater;
            out item mixed : PotableWater;
            mixed.temperature = ((cold.temperature * coldWaterDemand) + (hot.temperature * hotWaterDemand)) / (coldWaterDemand + hotWaterDemand);
            mixed.pressure = min(cold.pressure, hot.pressure);
            mixed.flowRate = coldWaterDemand + hotWaterDemand;
            mixed.quality = min(cold.quality, hot.quality);
        }

        action dischargeWaste {
            in item usedWater : PotableWater;
            out item waste : WasteWater;
            waste.temperature = usedWater.temperature;
            waste.flowRate = usedWater.flowRate;
            waste.contaminantLoad = 0.65;
        }
    }

    part def VentStack {
        attribute height : Length;
        attribute nominalDiameter : PipeDiameter;
        attribute atmosphericPressure : Pressure;

        port drainVentConnection : VentPort;
        port roofTermination : VentPort;
    }

    part def Trap {
        attribute sealDepth : Length;
        attribute retainedWaterVolume : Volume;

        port fixtureSide : WasteInletPort;
        port drainSide : WasteOutletPort;
        port ventSide : VentPort;

        action blockSewerGas {
            in item ventAir : VentAir;
            out attribute sealed : Boolean;
            sealed = retainedWaterVolume > 0.2;
        }
    }

    part def PlumbingSystem {
        attribute designSupplyPressure : Pressure = 420.0;
        attribute minimumServicePressure : Pressure = 210.0;
        attribute maximumServicePressure : Pressure = 550.0;
        attribute designTotalFlow : FlowRate = 95.0;
        attribute primaryFunction : String = "Distribute potable water to fixtures and safely remove wastewater through drainage and venting.";

        port municipalSupply : WaterInletPort;
        port sewerConnection : WasteOutletPort;
        port roofVent : VentPort;

        part mainShutoff : ShutoffValve {
            attribute ratedPressure = 1000.0;
        }

        part regulator : PressureRegulator {
            attribute targetOutletPressure = 420.0;
            attribute maximumFlow = 120.0;
        }

        part coldWaterHeader : PipeSegment {
            attribute length = 18.0;
            attribute insideDiameter = 32.0;
            attribute ratedPressure = 1000.0;
        }

        part waterHeater : WaterHeater {
            attribute tankCapacity = 190.0;
            attribute setpointTemperature = 49.0;
            attribute maximumPressure = 850.0;
        }

        part hotWaterHeader : PipeSegment {
            attribute length = 14.0;
            attribute insideDiameter = 25.0;
            attribute ratedPressure = 1000.0;
        }

        part kitchenSink : Fixture {
            attribute fixtureName = "Kitchen Sink";
            attribute requiredFlow = 8.0;
            attribute minimumPressure = 210.0;
            attribute hotWaterDemand = 4.0;
            attribute coldWaterDemand = 4.0;
        }

        part bathroomLavatory : Fixture {
            attribute fixtureName = "Bathroom Lavatory";
            attribute requiredFlow = 6.0;
            attribute minimumPressure = 210.0;
            attribute hotWaterDemand = 3.0;
            attribute coldWaterDemand = 3.0;
        }

        part shower : Fixture {
            attribute fixtureName = "Shower";
            attribute requiredFlow = 9.5;
            attribute minimumPressure = 240.0;
            attribute hotWaterDemand = 5.5;
            attribute coldWaterDemand = 4.0;
        }

        part toilet : Fixture {
            attribute fixtureName = "Toilet";
            attribute requiredFlow = 7.0;
            attribute minimumPressure = 210.0;
            attribute hotWaterDemand = 0.0;
            attribute coldWaterDemand = 7.0;
        }

        part kitchenTrap : Trap {
            attribute sealDepth = 0.05;
            attribute retainedWaterVolume = 0.35;
        }

        part lavatoryTrap : Trap {
            attribute sealDepth = 0.05;
            attribute retainedWaterVolume = 0.25;
        }

        part showerTrap : Trap {
            attribute sealDepth = 0.05;
            attribute retainedWaterVolume = 0.45;
        }

        part drainBranch : DrainPipeSegment {
            attribute length = 16.0;
            attribute insideDiameter = 75.0;
            attribute slope = 0.02;
        }

        part soilStack : DrainPipeSegment {
            attribute length = 9.0;
            attribute insideDiameter = 100.0;
            attribute slope = 1.0;
        }

        part ventStack : VentStack {
            attribute height = 10.5;
            attribute nominalDiameter = 75.0;
            attribute atmosphericPressure = 101.3;
        }

        connect municipalSupply to mainShutoff.inlet;
        connect mainShutoff.outlet to regulator.inlet;
        connect regulator.outlet to coldWaterHeader.inlet;
        connect coldWaterHeader.outlet to waterHeater.coldInlet;
        connect waterHeater.hotOutlet to hotWaterHeader.inlet;

        connect coldWaterHeader.outlet to kitchenSink.coldSupply;
        connect coldWaterHeader.outlet to bathroomLavatory.coldSupply;
        connect coldWaterHeader.outlet to shower.coldSupply;
        connect coldWaterHeader.outlet to toilet.coldSupply;

        connect hotWaterHeader.outlet to kitchenSink.hotSupply;
        connect hotWaterHeader.outlet to bathroomLavatory.hotSupply;
        connect hotWaterHeader.outlet to shower.hotSupply;

        connect kitchenSink.drainOutlet to kitchenTrap.fixtureSide;
        connect bathroomLavatory.drainOutlet to lavatoryTrap.fixtureSide;
        connect shower.drainOutlet to showerTrap.fixtureSide;

        connect kitchenTrap.drainSide to drainBranch.inlet;
        connect lavatoryTrap.drainSide to drainBranch.inlet;
        connect showerTrap.drainSide to drainBranch.inlet;
        connect toilet.drainOutlet to soilStack.inlet;
        connect drainBranch.outlet to soilStack.inlet;
        connect soilStack.outlet to sewerConnection;

        connect kitchenTrap.ventSide to ventStack.drainVentConnection;
        connect lavatoryTrap.ventSide to ventStack.drainVentConnection;
        connect showerTrap.ventSide to ventStack.drainVentConnection;
        connect drainBranch.vent to ventStack.drainVentConnection;
        connect ventStack.roofTermination to roofVent;

        action providePlumbingService {
            in item supplyWater : PotableWater;
            out item deliveredWater : PotableWater;
            out item removedWaste : WasteWater;

            deliveredWater.pressure = regulator.targetOutletPressure;
            deliveredWater.flowRate = min(supplyWater.flowRate, designTotalFlow);
            deliveredWater.temperature = supplyWater.temperature;
            deliveredWater.quality = supplyWater.quality;

            removedWaste.flowRate = deliveredWater.flowRate;
            removedWaste.temperature = deliveredWater.temperature;
            removedWaste.contaminantLoad = 0.70;
        }

        state def SystemOperatingState {
            state isolated;
            state pressurizing;
            state normalService;
            state reducedService;
            state drainOnly;
            state faultIsolation;

            transition first isolated;

            transition isolated_to_pressurizing
                first isolated
                then pressurizing
                if mainShutoff.open == true;

            transition pressurizing_to_normal
                first pressurizing
                then normalService
                if regulator.outletPressure >= minimumServicePressure and regulator.outletPressure <= maximumServicePressure;

            transition normal_to_reduced
                first normalService
                then reducedService
                if regulator.outletPressure < minimumServicePressure;

            transition reduced_to_normal
                first reducedService
                then normalService
                if regulator.outletPressure >= minimumServicePressure;

            transition normal_to_drainOnly
                first normalService
                then drainOnly
                if mainShutoff.open == false;

            transition overpressure_to_fault
                first normalService
                then faultIsolation
                if regulator.outletPressure > maximumServicePressure;

            transition fault_to_isolated
                first faultIsolation
                then isolated
                do {
                    mainShutoff.open = false;
                }
        }

        behavior operatingBehavior : SystemOperatingState;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The plumbing system shall distribute potable water to connected fixtures at usable pressure and flow while conveying wastewater to the sewer and maintaining sanitary venting. */

        subject system : PlumbingSystem;

        require constraint {
            system.primaryFunction == "Distribute potable water to fixtures and safely remove wastewater through drainage and venting."
        }
    }

    requirement def SupplyPressureRequirement {
        doc /* The plumbing system shall maintain fixture supply pressure within the normal service range during expected simultaneous demand. */

        subject system : PlumbingSystem;

        require constraint {
            system.regulator.outletPressure >= system.minimumServicePressure and
            system.regulator.outletPressure <= system.maximumServicePressure
        }
    }

    requirement def FlowCapacityRequirement {
        doc /* The plumbing system shall support the combined design fixture flow without exceeding the regulated supply capacity. */

        subject system : PlumbingSystem;

        require constraint {
            system.kitchenSink.requiredFlow +
            system.bathroomLavatory.requiredFlow +
            system.shower.requiredFlow +
            system.toilet.requiredFlow <= system.designTotalFlow
        }
    }

    requirement def HotWaterRequirement {
        doc /* The plumbing system shall heat stored potable water to the configured service temperature for fixtures requiring hot water. */

        subject heater : WaterHeater;

        require constraint {
            heater.currentTemperature <= heater.setpointTemperature and
            heater.setpointTemperature >= 45.0 and
            heater.setpointTemperature <= 60.0
        }
    }

    requirement def DrainageRequirement {
        doc /* The drainage subsystem shall convey fixture wastewater to the sewer connection without reverse flow into fixtures. */

        subject system : PlumbingSystem;

        require constraint {
            system.drainBranch.slope >= 0.01 and
            system.soilStack.insideDiameter >= system.drainBranch.insideDiameter
        }
    }

    requirement def TrapSealRequirement {
        doc /* Each fixture trap shall retain sufficient water seal volume to block sewer gas from entering occupied space. */

        subject trap : Trap;

        require constraint {
            trap.retainedWaterVolume >= 0.2 and
            trap.sealDepth >= 0.05
        }
    }

    requirement def VentingRequirement {
        doc /* The vent stack shall maintain drainage air pressure near atmospheric conditions and terminate above the roof. */

        subject vent : VentStack;

        require constraint {
            vent.height >= 3.0 and
            vent.nominalDiameter >= 50.0
        }
    }

    satisfy PrimaryFunctionRequirement by PlumbingSystem;
    satisfy SupplyPressureRequirement by PlumbingSystem;
    satisfy FlowCapacityRequirement by PlumbingSystem;
    satisfy HotWaterRequirement by PlumbingSystem::waterHeater;
    satisfy DrainageRequirement by PlumbingSystem;
    satisfy TrapSealRequirement by PlumbingSystem::kitchenTrap;
    satisfy TrapSealRequirement by PlumbingSystem::lavatoryTrap;
    satisfy TrapSealRequirement by PlumbingSystem::showerTrap;
    satisfy VentingRequirement by PlumbingSystem::ventStack;
}