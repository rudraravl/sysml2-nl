package 'Residential Plumbing System' {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def WaterPressure :> ISQ::PressureValue;
    attribute def WaterFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def WaterTemperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def PipeDiameter :> ISQ::LengthValue;
    attribute def TankVolume :> ISQ::VolumeValue;

    item def Water {
        attribute temperature : WaterTemperature;
        attribute pressure : WaterPressure;
        attribute flowRate : WaterFlowRate;
    }

    port def WaterInletPort {
        in item water : Water;
    }

    port def WaterOutletPort {
        out item water : Water;
    }

    part def MunicipalWaterSupply {
        doc /* External water source providing pressurized water to the building. */
        port outlet : WaterOutletPort;
        attribute supplyPressure : WaterPressure = 400000.0;
        attribute supplyTemperature : WaterTemperature = 288.15;
    }

    part def MainShutoffValve {
        doc /* Primary isolation valve controlling water entry to the building. */
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        attribute isOpen : Boolean;
        attribute maxFlowRate : WaterFlowRate;
    }

    part def PressureRegulator {
        doc /* Reduces and stabilizes incoming water pressure to safe levels. */
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        attribute targetPressure : WaterPressure = 350000.0;
        attribute inletPressure : WaterPressure;
        attribute outletPressure : WaterPressure;
    }

    part def WaterMeter {
        doc /* Measures total water consumption for billing purposes. */
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        attribute totalVolume : TankVolume;
        attribute currentFlowRate : WaterFlowRate;
    }

    part def SupplyPipe {
        doc /* Conveys water between system components. */
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        attribute diameter : PipeDiameter;
        attribute length : ISQ::LengthValue;
        attribute material : String;
    }

    part def WaterHeater {
        doc /* Heats cold water to desired temperature for domestic use. */
        port coldInlet : WaterInletPort;
        port hotOutlet : WaterOutletPort;
        attribute tankCapacity : TankVolume = 0.15;
        attribute setpointTemperature : WaterTemperature = 333.15;
        attribute currentTemperature : WaterTemperature;
        attribute heatingPower : ISQ::PowerValue = 4500.0;

        state def HeaterControlStates {
            entry assign currentTemperature := 288.15;

            state Idle {
                doc /* Heater maintains temperature, no active heating. */
            }
            accept at Idle
                then Heating
                if currentTemperature < setpointTemperature - 5.0;

            state Heating {
                doc /* Heating element active, raising water temperature. */
            }
            accept at Heating
                then Idle
                if currentTemperature >= setpointTemperature;

            state Standby {
                doc /* Heater powered off for maintenance or safety. */
            }
        }
    }

    part def DistributionManifold {
        doc /* Splits water supply to multiple branch lines. */
        port mainInlet : WaterInletPort;
        port hotBranchOutlet : WaterOutletPort;
        port coldBranchOutlet : WaterOutletPort;
    }

    part def MixingValve {
        doc /* Blends hot and cold water to achieve desired temperature. */
        port hotInlet : WaterInletPort;
        port coldInlet : WaterInletPort;
        port mixedOutlet : WaterOutletPort;
        attribute hotRatio : Real;
        attribute coldRatio : Real;
        attribute targetOutletTemp : WaterTemperature = 313.15;
    }

    part def Fixture {
        doc /* End-use device for water delivery (sink, shower, toilet). */
        port waterInlet : WaterInletPort;
        port drainOutlet : WaterOutletPort;
        attribute fixtureType : String;
        attribute demandFlowRate : WaterFlowRate;
        attribute isActive : Boolean;
    }

    part def DrainPipe {
        doc /* Carries wastewater away from fixtures to sewer. */
        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        attribute diameter : PipeDiameter;
        attribute slope : Real;
    }

    part def SewerConnection {
        doc /* Interface to municipal sewer system for wastewater disposal. */
        port inlet : WaterInletPort;
    }

    action def RegulateSupplyPressure {
        in inletPressure : WaterPressure;
        in targetPressure : WaterPressure;
        out regulatedPressure : WaterPressure;
    }

    action def HeatWater {
        in coldWaterTemp : WaterTemperature;
        in setpoint : WaterTemperature;
        in power : ISQ::PowerValue;
        out hotWaterTemp : WaterTemperature;
    }

    action def MixWaterStreams {
        in hotTemp : WaterTemperature;
        in coldTemp : WaterTemperature;
        in hotFlow : WaterFlowRate;
        in coldFlow : WaterFlowRate;
        out mixedTemp : WaterTemperature;
        out mixedFlow : WaterFlowRate;
    }

    action def DeliverWaterToFixtures {
        doc /* Primary system behavior: supply water from source to end-use fixtures. */
        in supplyPressure : WaterPressure;
        in supplyTemp : WaterTemperature;
        out deliveredPressure : WaterPressure;
        out deliveredTemp : WaterTemperature;
        out deliveredFlow : WaterFlowRate;

        first start;
        then action regulatePressure : RegulateSupplyPressure {
            in inletPressure = supplyPressure;
            in targetPressure;
            out regulatedPressure;
        }
        then merge splitFlow;
        then action splitToColdAndHot {
            out coldBranchFlow : WaterFlowRate;
            out hotBranchFlow : WaterFlowRate;
        }
        then action heatHotBranch : HeatWater {
            in coldWaterTemp = supplyTemp;
            in setpoint;
            in power;
            out hotWaterTemp;
        }
        then action mixStreams : MixWaterStreams {
            in hotTemp = heatHotBranch.hotWaterTemp;
            in coldTemp = supplyTemp;
            in hotFlow = splitToColdAndHot.hotBranchFlow;
            in coldFlow = splitToColdAndHot.coldBranchFlow;
            out mixedTemp;
            out mixedFlow;
        }
        then assign deliveredPressure := regulatePressure.regulatedPressure;
        then assign deliveredTemp := mixStreams.mixedTemp;
        then assign deliveredFlow := mixStreams.mixedFlow;
        then done;
    }

    requirement def PressureSafetyRequirement {
        doc /* Water pressure at fixtures shall not exceed safe operating limits. */
        attribute maxAllowablePressure : WaterPressure = 550000.0;
    }

    requirement def TemperatureSafetyRequirement {
        doc /* Hot water temperature shall not exceed scalding threshold. */
        attribute maxSafeTemperature : WaterTemperature = 338.15;
    }

    requirement def FlowCapacityRequirement {
        doc /* System shall deliver minimum flow rate to all active fixtures simultaneously. */
        attribute minFlowRate : WaterFlowRate = 0.0001;
    }

    requirement def DrainageRequirement {
        doc /* Drainage system shall remove wastewater without backup or overflow. */
    }

    requirement systemFunctionalRequirements {
        doc /* The plumbing system shall safely and reliably deliver potable water to all fixtures and remove wastewater. */
        require pressureSafety : PressureSafetyRequirement;
        require temperatureSafety : TemperatureSafetyRequirement;
        require flowCapacity : FlowCapacityRequirement;
        require drainage : DrainageRequirement;
    }

    part residentialPlumbing {
        doc /* 
        A residential plumbing system that receives pressurized water from a municipal supply,
        regulates pressure, heats a portion for domestic use, distributes both hot and cold water
        to various fixtures throughout the building, and safely removes wastewater to the sewer.
        The primary function is to provide continuous, safe, and reliable water delivery at
        appropriate pressure and temperature while ensuring proper drainage.
        */

        part municipalSupply : MunicipalWaterSupply;
        part mainValve : MainShutoffValve;
        part regulator : PressureRegulator;
        part meter : WaterMeter;
        part coldMainPipe : SupplyPipe {
            attribute diameter = 0.019;
            attribute material = "Copper";
        }
        part heater : WaterHeater {
            perform action heating : HeatWater;
        }
        part hotMainPipe : SupplyPipe {
            attribute diameter = 0.019;
            attribute material = "Copper";
        }
        part manifold : DistributionManifold;
        part kitchenMixer : MixingValve;
        part bathroomMixer : MixingValve;
        part kitchenSink : Fixture {
            attribute fixtureType = "Kitchen Sink";
            attribute demandFlowRate = 0.00012;
        }
        part bathroomSink : Fixture {
            attribute fixtureType = "Bathroom Sink";
            attribute demandFlowRate = 0.00008;
        }
        part shower : Fixture {
            attribute fixtureType = "Shower";
            attribute demandFlowRate = 0.00015;
        }
        part toilet : Fixture {
            attribute fixtureType = "Toilet";
            attribute demandFlowRate = 0.0001;
        }
        part kitchenDrain : DrainPipe {
            attribute diameter = 0.038;
            attribute slope = 0.02;
        }
        part bathroomDrain : DrainPipe {
            attribute diameter = 0.038;
            attribute slope = 0.02;
        }
        part mainDrain : DrainPipe {
            attribute diameter = 0.076;
            attribute slope = 0.02;
        }
        part sewerConnection : SewerConnection;

        connect municipalSupply.outlet to mainValve.inlet;
        connect mainValve.outlet to regulator.inlet;
        connect regulator.outlet to meter.inlet;
        connect meter.outlet to coldMainPipe.inlet;
        connect coldMainPipe.outlet to heater.coldInlet;
        connect heater.hotOutlet to hotMainPipe.inlet;
        connect hotMainPipe.outlet to manifold.mainInlet;
        connect coldMainPipe.outlet to manifold.mainInlet;
        connect manifold.hotBranchOutlet to kitchenMixer.hotInlet;
        connect manifold.coldBranchOutlet to kitchenMixer.coldInlet;
        connect manifold.hotBranchOutlet to bathroomMixer.hotInlet;
        connect manifold.coldBranchOutlet to bathroomMixer.coldInlet;
        connect kitchenMixer.mixedOutlet to kitchenSink.waterInlet;
        connect bathroomMixer.mixedOutlet to bathroomSink.waterInlet;
        connect bathroomMixer.mixedOutlet to shower.waterInlet;
        connect manifold.coldBranchOutlet to toilet.waterInlet;
        connect kitchenSink.drainOutlet to kitchenDrain.inlet;
        connect bathroomSink.drainOutlet to bathroomDrain.inlet;
        connect shower.drainOutlet to bathroomDrain.inlet;
        connect toilet.drainOutlet to bathroomDrain.inlet;
        connect kitchenDrain.outlet to mainDrain.inlet;
        connect bathroomDrain.outlet to mainDrain.inlet;
        connect mainDrain.outlet to sewerConnection.inlet;

        perform action deliverWater : DeliverWaterToFixtures {
            in supplyPressure = municipalSupply.supplyPressure;
            in supplyTemp = municipalSupply.supplyTemperature;
            out deliveredPressure;
            out deliveredTemp;
            out deliveredFlow;
        }

        satisfy systemFunctionalRequirements;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import 'Residential Plumbing System'::*;

    part testSubject : MunicipalWaterSupply {
        exhibit state sm : HeaterControlStates;
    }

    action orchestrator {
        attribute testInletPressure : WaterPressure;
        attribute testTargetPressure : WaterPressure;
        action actionProbe : RegulateSupplyPressure {
            in inletPressure = testInletPressure;
            in targetPressure = testTargetPressure;
        }
        first actionProbe;
    }
}
