package EmberBasedSystemModel {

    import ScalarValues::*;
    import SI::*;

    unit def watt;
    unit def joule;
    unit def gram;
    unit def degreeCelsius;
    unit def percent;
    unit def lumen;
    unit def second;
    unit def minute;
    unit def literPerMinute;

    attribute def Temperature {
        :>> unit = degreeCelsius;
    }

    attribute def ThermalPower {
        :>> unit = watt;
    }

    attribute def Energy {
        :>> unit = joule;
    }

    attribute def Mass {
        :>> unit = gram;
    }

    attribute def OxygenFraction {
        :>> unit = percent;
    }

    attribute def LuminousFlux {
        :>> unit = lumen;
    }

    attribute def Duration {
        :>> unit = minute;
    }

    attribute def FlowRate {
        :>> unit = literPerMinute;
    }

    item def AmbientAir {
        attribute oxygenContent : OxygenFraction;
        attribute temperature : Temperature;
    }

    item def CombustionGas {
        attribute temperature : Temperature;
        attribute carbonDioxideFraction : OxygenFraction;
        attribute residualOxygenFraction : OxygenFraction;
    }

    item def RadiantHeat {
        attribute power : ThermalPower;
        attribute energyDelivered : Energy;
    }

    item def VisibleGlow {
        attribute flux : LuminousFlux;
        attribute colorTemperature : Temperature;
    }

    item def CharFuel {
        attribute remainingMass : Mass;
        attribute storedChemicalEnergy : Energy;
        attribute moistureFraction : OxygenFraction;
    }

    port def AirInletPort {
        in item air : AmbientAir;
    }

    port def GasOutletPort {
        out item exhaust : CombustionGas;
    }

    port def HeatOutputPort {
        out item heat : RadiantHeat;
    }

    port def LightOutputPort {
        out item glow : VisibleGlow;
    }

    port def FuelServicePort {
        inout item fuel : CharFuel;
    }

    port def ControlPort {
        in item requestedMode : EmberOperatingMode;
    }

    enum def EmberOperatingMode {
        enum idle;
        enum sustain;
        enum warm;
        enum signal;
        enum extinguish;
    }

    enum def EmberHealth {
        enum viable;
        enum oxygenStarved;
        enum overheated;
        enum fuelDepleted;
        enum extinguished;
    }

    part def EmberCore {
        port airIn : AirInletPort;
        port gasOut : GasOutletPort;
        port heatOut : HeatOutputPort;
        port lightOut : LightOutputPort;
        port fuelPort : FuelServicePort;

        attribute coreTemperature : Temperature = 520 [degreeCelsius];
        attribute heatReleaseRate : ThermalPower = 35 [watt];
        attribute visibleFlux : LuminousFlux = 4 [lumen];
        attribute fuelMass : Mass = 65 [gram];
        attribute burnDurationRemaining : Duration = 90 [minute];
        attribute health : EmberHealth = EmberHealth::viable;

        action maintainOxidation {
            in item incomingAir : AmbientAir;
            inout item carbonFuel : CharFuel;
            out item outgoingGas : CombustionGas;
            out item emittedHeat : RadiantHeat;
            out item emittedGlow : VisibleGlow;

            first start;
            then consumeOxygen;
            then releaseThermalEnergy;
            then emitVisibleGlow;
            then ventCombustionGas;
            then done;

            action consumeOxygen {
                in item incomingAir : AmbientAir;
                inout item carbonFuel : CharFuel;
            }

            action releaseThermalEnergy {
                out item emittedHeat : RadiantHeat;
            }

            action emitVisibleGlow {
                out item emittedGlow : VisibleGlow;
            }

            action ventCombustionGas {
                out item outgoingGas : CombustionGas;
            }
        }

        state def EmberLifecycle {
            entry action assessInitialFuel;

            state Dormant;
            state Igniting;
            state Sustaining;
            state Warming;
            state Signaling;
            state OxygenStarved;
            state Overheated;
            state FuelDepleted;
            state Extinguished;

            transition first Dormant;

            transition Dormant_to_Igniting
                first Dormant
                accept EmberOperatingMode::sustain
                then Igniting;

            transition Igniting_to_Sustaining
                first Igniting
                if coreTemperature >= 430 [degreeCelsius] and fuelMass > 5 [gram]
                then Sustaining;

            transition Sustaining_to_Warming
                first Sustaining
                accept EmberOperatingMode::warm
                then Warming;

            transition Sustaining_to_Signaling
                first Sustaining
                accept EmberOperatingMode::signal
                then Signaling;

            transition Warming_to_Sustaining
                first Warming
                accept EmberOperatingMode::sustain
                then Sustaining;

            transition Signaling_to_Sustaining
                first Signaling
                accept EmberOperatingMode::sustain
                then Sustaining;

            transition Any_to_OxygenStarved
                first Sustaining
                if airIn.air.oxygenContent < 12 [percent]
                then OxygenStarved;

            transition OxygenStarved_to_Sustaining
                first OxygenStarved
                if airIn.air.oxygenContent >= 18 [percent] and coreTemperature >= 380 [degreeCelsius]
                then Sustaining;

            transition Any_to_Overheated
                first Warming
                if coreTemperature > 760 [degreeCelsius]
                then Overheated;

            transition Any_to_FuelDepleted
                first Sustaining
                if fuelMass <= 2 [gram]
                then FuelDepleted;

            transition FuelDepleted_to_Extinguished
                first FuelDepleted
                then Extinguished;

            transition ExtinguishCommand
                first Sustaining
                accept EmberOperatingMode::extinguish
                then Extinguished;
        }
    }

    part def InsulatedCradle {
        port heatIn : HeatOutputPort;
        port heatOut : HeatOutputPort;

        attribute outerSurfaceTemperature : Temperature = 46 [degreeCelsius];
        attribute retainedThermalEnergy : Energy = 4200 [joule];
        attribute maximumSafeSurfaceTemperature : Temperature = 60 [degreeCelsius];

        action bufferHeat {
            in item receivedHeat : RadiantHeat;
            out item moderatedHeat : RadiantHeat;
        }
    }

    part def AirflowRegulator {
        port externalAir : AirInletPort;
        port regulatedAir : AirInletPort;
        port control : ControlPort;

        attribute apertureOpening : OxygenFraction = 45 [percent];
        attribute nominalFlow : FlowRate = 1.8 [literPerMinute];
        attribute minimumSustainFlow : FlowRate = 0.7 [literPerMinute];
        attribute maximumBoostFlow : FlowRate = 4.2 [literPerMinute];

        action regulateAirflow {
            in item requestedMode : EmberOperatingMode;
            in item ambient : AmbientAir;
            out item meteredAir : AmbientAir;

            first readMode;
            then setAperture;
            then passMeteredAir;
            then done;
        }
    }

    part def ExhaustVent {
        port gasIn : GasOutletPort;
        port gasOut : GasOutletPort;

        attribute outletTemperature : Temperature = 140 [degreeCelsius];
        attribute backPressureLimit : FlowRate = 0.3 [literPerMinute];

        action coolAndVent {
            in item hotGas : CombustionGas;
            out item safeExhaust : CombustionGas;
        }
    }

    part def FuelCartridge {
        port service : FuelServicePort;

        attribute initialFuelMass : Mass = 80 [gram];
        attribute availableFuelMass : Mass = 65 [gram];
        attribute usableChemicalEnergy : Energy = 960000 [joule];
        attribute moistureFraction : OxygenFraction = 4 [percent];

        action feedChar {
            out item suppliedFuel : CharFuel;
        }
    }

    part def ThermalOutputInterface {
        port heatIn : HeatOutputPort;
        port userHeatOut : HeatOutputPort;
        port glowIn : LightOutputPort;
        port userGlowOut : LightOutputPort;

        attribute deliveredHeatPower : ThermalPower = 25 [watt];
        attribute deliveredGlowFlux : LuminousFlux = 3 [lumen];

        action presentUsefulOutput {
            in item bufferedHeat : RadiantHeat;
            in item emberGlow : VisibleGlow;
            out item usefulHeat : RadiantHeat;
            out item statusGlow : VisibleGlow;
        }
    }

    part def EmberBasedThermalBeacon {
        doc /* Primary function: sustain a controlled ember to convert stored char fuel and ambient oxygen into low-intensity heat and visible glow for warming, signaling, and ignition support. */

        port ambientAirIn : AirInletPort;
        port exhaustOut : GasOutletPort;
        port usefulHeatOut : HeatOutputPort;
        port visibleStatusOut : LightOutputPort;
        port fuelService : FuelServicePort;
        port commandIn : ControlPort;

        part ember : EmberCore;
        part cradle : InsulatedCradle;
        part airflow : AirflowRegulator;
        part vent : ExhaustVent;
        part cartridge : FuelCartridge;
        part output : ThermalOutputInterface;

        attribute operatingMode : EmberOperatingMode = EmberOperatingMode::sustain;
        attribute systemHealth : EmberHealth = EmberHealth::viable;
        attribute minimumUsefulHeat : ThermalPower = 20 [watt];
        attribute nominalUsefulHeat : ThermalPower = 25 [watt];
        attribute peakUsefulHeat : ThermalPower = 55 [watt];
        attribute minimumVisibleGlow : LuminousFlux = 1 [lumen];
        attribute minimumSustainDuration : Duration = 60 [minute];
        attribute safeTouchTemperatureLimit : Temperature = 60 [degreeCelsius];

        connect ambient_air_path from ambientAirIn to airflow.externalAir;
        connect regulated_air_path from airflow.regulatedAir to ember.airIn;
        connect command_path from commandIn to airflow.control;
        connect fuel_service_path from fuelService to cartridge.service;
        connect cartridge_feed_path from cartridge.service to ember.fuelPort;
        connect raw_heat_path from ember.heatOut to cradle.heatIn;
        connect buffered_heat_path from cradle.heatOut to output.heatIn;
        connect glow_path from ember.lightOut to output.glowIn;
        connect useful_heat_path from output.userHeatOut to usefulHeatOut;
        connect visible_status_path from output.userGlowOut to visibleStatusOut;
        connect raw_exhaust_path from ember.gasOut to vent.gasIn;
        connect safe_exhaust_path from vent.gasOut to exhaustOut;

        action operate {
            in item ambient : AmbientAir;
            in item command : EmberOperatingMode;
            inout item fuel : CharFuel;
            out item usefulHeat : RadiantHeat;
            out item visibleGlow : VisibleGlow;
            out item exhaust : CombustionGas;

            first receiveCommand;
            then meterAir;
            then sustainEmber;
            then bufferThermalOutput;
            then presentOutput;
            then ventExhaust;
            then updateHealth;
            then done;

            action receiveCommand {
                in item command : EmberOperatingMode;
            }

            action meterAir {
                in item ambient : AmbientAir;
                out item meteredAir : AmbientAir;
            }

            action sustainEmber {
                in item meteredAir : AmbientAir;
                inout item fuel : CharFuel;
                out item rawHeat : RadiantHeat;
                out item rawGlow : VisibleGlow;
                out item rawGas : CombustionGas;
            }

            action bufferThermalOutput {
                in item rawHeat : RadiantHeat;
                out item bufferedHeat : RadiantHeat;
            }

            action presentOutput {
                in item bufferedHeat : RadiantHeat;
                in item rawGlow : VisibleGlow;
                out item usefulHeat : RadiantHeat;
                out item visibleGlow : VisibleGlow;
            }

            action ventExhaust {
                in item rawGas : CombustionGas;
                out item exhaust : CombustionGas;
            }

            action updateHealth {
                out attribute systemHealth : EmberHealth;
            }
        }

        state def SystemState {
            state Off;
            state Starting;
            state SustainedEmber;
            state HeatBoost;
            state SignalGlow;
            state Cooling;
            state Fault;
            state Out;

            transition initial_to_off first Off;

            transition start_sustain
                first Off
                accept EmberOperatingMode::sustain
                then Starting;

            transition ignition_confirmed
                first Starting
                if ember.coreTemperature >= 430 [degreeCelsius]
                then SustainedEmber;

            transition request_heat
                first SustainedEmber
                accept EmberOperatingMode::warm
                then HeatBoost;

            transition request_signal
                first SustainedEmber
                accept EmberOperatingMode::signal
                then SignalGlow;

            transition return_from_heat
                first HeatBoost
                accept EmberOperatingMode::sustain
                then SustainedEmber;

            transition return_from_signal
                first SignalGlow
                accept EmberOperatingMode::sustain
                then SustainedEmber;

            transition cool_down
                first SustainedEmber
                accept EmberOperatingMode::extinguish
                then Cooling;

            transition cooled
                first Cooling
                if ember.coreTemperature < 90 [degreeCelsius]
                then Off;

            transition fault_overheat
                first HeatBoost
                if cradle.outerSurfaceTemperature > safeTouchTemperatureLimit
                then Fault;

            transition fault_starved
                first SustainedEmber
                if ambientAirIn.air.oxygenContent < 10 [percent]
                then Fault;

            transition fuel_empty
                first SustainedEmber
                if cartridge.availableFuelMass <= 2 [gram]
                then Out;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall use an ember as its central conversion element to provide sustained useful heat and visible glow from char fuel and ambient air. */

        subject system : EmberBasedThermalBeacon;

        require constraint {
            system.nominalUsefulHeat >= 25 [watt]
        }

        require constraint {
            system.minimumVisibleGlow >= 1 [lumen]
        }

        require constraint {
            system.minimumSustainDuration >= 60 [minute]
        }
    }

    requirement def ControlledCombustionRequirement {
        subject system : EmberBasedThermalBeacon;

        require constraint {
            system.ember.coreTemperature >= 380 [degreeCelsius] and
            system.ember.coreTemperature <= 760 [degreeCelsius]
        }

        require constraint {
            system.airflow.nominalFlow >= system.airflow.minimumSustainFlow and
            system.airflow.nominalFlow <= system.airflow.maximumBoostFlow
        }
    }

    requirement def UserSafetyRequirement {
        subject system : EmberBasedThermalBeacon;

        require constraint {
            system.cradle.outerSurfaceTemperature <= system.safeTouchTemperatureLimit
        }

        require constraint {
            system.exhaustOut.exhaust.temperature <= 180 [degreeCelsius]
        }
    }

    requirement def FuelEnduranceRequirement {
        subject system : EmberBasedThermalBeacon;

        require constraint {
            system.cartridge.availableFuelMass >= 40 [gram]
        }

        require constraint {
            system.cartridge.usableChemicalEnergy >= 600000 [joule]
        }
    }

    requirement def ExhaustQualityRequirement {
        subject system : EmberBasedThermalBeacon;

        require constraint {
            system.exhaustOut.exhaust.residualOxygenFraction >= 4 [percent]
        }

        require constraint {
            system.exhaustOut.exhaust.carbonDioxideFraction <= 12 [percent]
        }
    }

    satisfy PrimaryFunctionRequirement by EmberBasedThermalBeacon;
    satisfy ControlledCombustionRequirement by EmberBasedThermalBeacon::ember;
    satisfy UserSafetyRequirement by EmberBasedThermalBeacon::cradle;
    satisfy FuelEnduranceRequirement by EmberBasedThermalBeacon::cartridge;
    satisfy ExhaustQualityRequirement by EmberBasedThermalBeacon::vent;

}