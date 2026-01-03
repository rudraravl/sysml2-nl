package 'Synthetic Diamond Laser System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def OpticalPowerValue :> ISQ::PowerValue;
    attribute def WavelengthValue :> ISQ::LengthValue;
    attribute def BeamQualityFactor :> Real;
    attribute def ThermalConductivityValue :> ISQ::ThermalConductivityValue;
    attribute def CrystalPurityValue :> Real;

    item def ElectricalPower {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
        attribute power : ISQ::PowerValue;
    }

    item def OpticalBeam {
        attribute power : OpticalPowerValue;
        attribute wavelength : WavelengthValue;
        attribute beamQuality : BeamQualityFactor;
    }

    item def CoolantFluid {
        attribute flowRate : ISQ::VolumeFlowRateValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
    }

    attribute def LaserEnableCommand;
    attribute def LaserDisableCommand;
    attribute def EmergencyShutdown;
    attribute def TemperatureAlert;

    port def ElectricalPort {
        in item electricalSupply : ElectricalPower;
    }

    port def OpticalPort {
        out item laserOutput : OpticalBeam;
    }

    port def CoolantPort {
        in item coolantIn : CoolantFluid;
        out item coolantOut : CoolantFluid;
    }

    port def ControlPort {
        in attribute enableCmd : LaserEnableCommand;
        in attribute disableCmd : LaserDisableCommand;
        out attribute tempAlert : TemperatureAlert;
    }

    part def PowerSupplyUnit {
        attribute maxPower : ISQ::PowerValue;
        attribute efficiency : Real;
        port electricalOut : ElectricalPort;
    }

    part def DiodePumpArray {
        attribute numberOfDiodes : Integer;
        attribute pumpWavelength : WavelengthValue;
        attribute totalPumpPower : OpticalPowerValue;
        port electricalIn : ElectricalPort;
        port pumpOut : OpticalPort;
    }

    part def SyntheticDiamondGainMedium {
        attribute crystalLength : ISQ::LengthValue;
        attribute crystalDiameter : ISQ::LengthValue;
        attribute thermalConductivity : ThermalConductivityValue;
        attribute nitrogenDoping : CrystalPurityValue;
        attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
        port pumpIn : OpticalPort;
        port laserOut : OpticalPort;
        port cooling : CoolantPort;
    }

    part def ResonatorMirrors {
        attribute reflectivity : Real;
        attribute curvatureRadius : ISQ::LengthValue;
        port opticalInterface : OpticalPort;
    }

    part def ThermalManagementSystem {
        attribute coolingCapacity : ISQ::PowerValue;
        attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
        port coolantSupply : CoolantPort;
        port coolantReturn : CoolantPort;
    }

    part def TemperatureSensor {
        attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute threshold : ISQ::ThermodynamicTemperatureValue;
    }

    part def LaserController {
        attribute controlFrequency : ISQ::FrequencyValue;
        port control : ControlPort;
    }

    action def InitializeLaser {
        in powerLevel : ISQ::PowerValue;
        out systemReady : Boolean;
    }

    action def PumpDiamond {
        in pumpPower : OpticalPowerValue;
        in pumpWavelength : WavelengthValue;
        out excitedState : Boolean;
    }

    action def GenerateLaserEmission {
        in excitedMedium : Boolean;
        in resonatorQuality : Real;
        out laserBeam : OpticalBeam;
    }

    action def MonitorTemperature {
        in currentTemp : ISQ::ThermodynamicTemperatureValue;
        in maxTemp : ISQ::ThermodynamicTemperatureValue;
        out withinLimits : Boolean;
    }

    action def RegulateTemperature {
        in measuredTemp : ISQ::ThermodynamicTemperatureValue;
        in targetTemp : ISQ::ThermodynamicTemperatureValue;
        out coolantFlow : ISQ::VolumeFlowRateValue;
    }

    action def ShutdownLaser {
        out powerOff : Boolean;
    }

    action def OperateLaser {
        in targetPower : OpticalPowerValue;
        in targetWavelength : WavelengthValue;
        out outputBeam : OpticalBeam;

        first start;
        then action initialize : InitializeLaser {
            in powerLevel = 5000[W];
            out systemReady;
        }
        then merge operationLoop;
        then action pumpAction : PumpDiamond {
            in pumpPower = 8000[W];
            in pumpWavelength = 808[nm];
            out excitedState;
        }
        then action generateBeam : GenerateLaserEmission {
            in excitedMedium = pumpAction.excitedState;
            in resonatorQuality = 0.95;
            out laserBeam;
        }
        then action monitorTemp : MonitorTemperature {
            in currentTemp = 350[K];
            in maxTemp = 400[K];
            out withinLimits;
        }
        then decide;
            if monitorTemp.withinLimits then regulate;
            if !monitorTemp.withinLimits then shutdown;
        action regulate : RegulateTemperature {
            in measuredTemp = 350[K];
            in targetTemp = 320[K];
            out coolantFlow;
        }
        then operationLoop;
        action shutdown : ShutdownLaser {
            out powerOff;
        }
        then done;
    }

    state def LaserOperationalStates {
        attribute currentMode : String;
        attribute systemReady : Boolean;
        attribute tempOutOfRange : Boolean;
        attribute cooledToSafe : Boolean;
        attribute systemReset : Boolean;

        entry; then standby;

        state standby;
        
        transition standby_to_warmup
            first standby
            accept LaserEnableCommand
            then warmup;

        state warmup;
        
        transition warmup_to_lasing
            first warmup
            if systemReady
            then lasing;

        state lasing {
            state monitoring {
                entry; then checkTemp;
                state checkTemp;
                transition checkTemp_to_adjust
                    first checkTemp
                    if tempOutOfRange
                    then adjustCooling;
                state adjustCooling;
                transition adjustCooling_to_checkTemp
                    first adjustCooling
                    then checkTemp;
            }
        }
        
        transition lasing_to_cooldown
            first lasing
            accept LaserDisableCommand
            then cooldown;

        transition lasing_to_emergency
            first lasing
            accept EmergencyShutdown
            then emergency;

        state cooldown;
        
        transition cooldown_to_standby
            first cooldown
            if cooledToSafe
            then standby;

        state emergency;
        
        transition emergency_to_standby
            first emergency
            if systemReset
            then standby;
    }

    part syntheticDiamondLaser : SyntheticDiamondLaserSystem {
        doc /*
            High-Level Function:
            This system produces a high-power, continuous-wave laser beam using a synthetic 
            diamond crystal as the gain medium. The synthetic diamond's exceptional thermal 
            conductivity (2000 W/m·K) and optical properties enable efficient heat dissipation 
            and high-quality beam generation at kilowatt power levels.
            
            The primary function is to convert electrical energy into coherent optical radiation 
            at 1064 nm wavelength by optically pumping nitrogen-vacancy centers in the diamond 
            crystal with diode lasers, creating population inversion and stimulated emission 
            within an optical resonator cavity. The system maintains precise thermal control 
            to ensure stable operation and beam quality for applications in materials processing, 
            scientific research, and directed energy systems.
        */

        attribute targetOutputPower : OpticalPowerValue = 10000[W];
        attribute operatingWavelength : WavelengthValue = 1064[nm];
        attribute maxCrystalTemp : ISQ::ThermodynamicTemperatureValue = 400[K];

        perform action laserOperation : OperateLaser {
            in targetPower = targetOutputPower;
            in targetWavelength = operatingWavelength;
            out outputBeam;
        }

        exhibit state machine operationalState : LaserOperationalStates;

        part powerSupply : PowerSupplyUnit {
            attribute :>> maxPower = 12000[W];
            attribute :>> efficiency = 0.92;
            perform laserOperation.initialize;
        }

        part pumpDiodes : DiodePumpArray {
            attribute :>> numberOfDiodes = 24;
            attribute :>> pumpWavelength = 808[nm];
            attribute :>> totalPumpPower = 8000[W];
            perform laserOperation.pumpAction;
        }

        part diamondCrystal : SyntheticDiamondGainMedium {
            attribute :>> crystalLength = 10[mm];
            attribute :>> crystalDiameter = 5[mm];
            attribute :>> thermalConductivity = 2000[W/(m*K)];
            attribute :>> nitrogenDoping = 1.0e-6;
            attribute :>> operatingTemperature = 320[K];
            perform laserOperation.generateBeam;
        }

        part outputCoupler : ResonatorMirrors {
            attribute :>> reflectivity = 0.85;
            attribute :>> curvatureRadius = 500[mm];
        }

        part highReflector : ResonatorMirrors {
            attribute :>> reflectivity = 0.999;
            attribute :>> curvatureRadius = 1000[mm];
        }

        part coolingSystem : ThermalManagementSystem {
            attribute :>> coolingCapacity = 6000[W];
            attribute :>> targetTemperature = 320[K];
            perform laserOperation.regulate;
        }

        part tempSensor : TemperatureSensor {
            attribute :>> currentTemperature = 320[K];
            attribute :>> threshold = maxCrystalTemp;
            perform laserOperation.monitorTemp;
        }

        part controller : LaserController {
            attribute :>> controlFrequency = 1000[Hz];
        }

        connect powerSupply.electricalOut to pumpDiodes.electricalIn;
        connect pumpDiodes.pumpOut to diamondCrystal.pumpIn;
        connect diamondCrystal.laserOut to outputCoupler.opticalInterface;
        connect coolingSystem.coolantSupply to diamondCrystal.cooling;
    }

    part def SyntheticDiamondLaserSystem;

    requirement def OutputPowerRequirement {
        doc /* The laser system shall deliver a minimum continuous-wave output power. */
        subject laserSystem : SyntheticDiamondLaserSystem;
        require constraint {
            laserSystem.laserOperation.outputBeam.power >= 10000[W]
        }
    }

    requirement def BeamQualityRequirement {
        doc /* The output beam shall maintain near-diffraction-limited quality. */
        subject laserSystem : SyntheticDiamondLaserSystem;
        require constraint {
            laserSystem.laserOperation.outputBeam.beamQuality <= 1.2
        }
    }

    requirement def WavelengthStabilityRequirement {
        doc /* The output wavelength shall be stable within specified tolerance. */
        subject laserSystem : SyntheticDiamondLaserSystem;
        require constraint {
            laserSystem.laserOperation.outputBeam.wavelength >= 1063[nm] and
            laserSystem.laserOperation.outputBeam.wavelength <= 1065[nm]
        }
    }

    requirement def ThermalSafetyRequirement {
        doc /* The diamond crystal temperature shall not exceed safe operating limits. */
        subject laserSystem : SyntheticDiamondLaserSystem;
        require constraint {
            laserSystem.diamondCrystal.operatingTemperature <= 400[K]
        }
    }

    requirement def SystemEfficiencyRequirement {
        doc /* The overall optical-to-optical efficiency shall exceed minimum threshold. */
        subject laserSystem : SyntheticDiamondLaserSystem;
        attribute minEfficiency : Real = 0.25;
        require constraint {
            laserSystem.laserOperation.outputBeam.power / 
            laserSystem.pumpDiodes.totalPumpPower >= minEfficiency
        }
    }

    requirement <'SDL-001'> syntheticDiamondLaserRequirements {
        doc /* Top-level requirements for synthetic diamond laser system performance and safety. */

        require OutputPowerRequirement;
        require BeamQualityRequirement;
        require WavelengthStabilityRequirement;
        require ThermalSafetyRequirement;
        require SystemEfficiencyRequirement;

        assume constraint diamondQualityAssumption {
            doc /* The synthetic diamond crystal shall have thermal conductivity exceeding 1800 W/m·K. */
            SyntheticDiamondGainMedium::thermalConductivity >= 1800[W/(m*K)]
        }

        assume constraint pumpPowerAssumption {
            doc /* Pump diode array shall deliver stable power within 2% variation. */
            DiodePumpArray::totalPumpPower >= 7800[W]
        }
    }
}
