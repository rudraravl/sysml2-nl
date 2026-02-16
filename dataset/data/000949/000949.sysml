package TrompeAirCompressionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WaterFlowRateValue :> VolumeFlowRateValue;
    attribute def AirFlowRateValue :> VolumeFlowRateValue;
    attribute def WaterHeadValue :> LengthValue;
    attribute def AirPressureValue :> PressureValue;
    attribute def ShaftDepthValue :> LengthValue;
    attribute def WaterDensityValue :> DensityValue;
    
    item def FallingWater {
        attribute flowRate : WaterFlowRateValue;
        attribute velocity : SpeedValue;
        attribute head : WaterHeadValue;
    }
    
    item def AtmosphericAir {
        attribute pressure : AirPressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    item def WaterAirMixture {
        attribute waterFlowRate : WaterFlowRateValue;
        attribute airFlowRate : AirFlowRateValue;
        attribute velocity : SpeedValue;
        attribute pressure : AirPressureValue;
    }
    
    item def CompressedAir {
        attribute pressure : AirPressureValue;
        attribute flowRate : AirFlowRateValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    item def DischargedWater {
        attribute flowRate : WaterFlowRateValue;
        attribute pressure : AirPressureValue;
    }
    
    port def WaterSupplyPort {
        in item waterSupply : FallingWater;
    }
    
    port def AirIntakePort {
        in item airIntake : AtmosphericAir;
    }
    
    port def MixtureTransferPort {
        out item mixture : WaterAirMixture;
    }
    
    port def CompressedAirPort {
        out item compressedAir : CompressedAir;
    }
    
    port def WaterDischargePort {
        out item dischargedWater : DischargedWater;
    }
    
    part def IntakeSection {
        port waterIn : WaterSupplyPort;
        port airIn : AirIntakePort;
        port mixtureOut : MixtureTransferPort;
        
        attribute intakeDiameter : LengthValue;
        attribute airEntrainmentRatio : Real;
    }
    
    part def VerticalShaft {
        port mixtureIn : MixtureTransferPort;
        port mixtureOut : MixtureTransferPort;
        
        attribute shaftDepth : ShaftDepthValue;
        attribute shaftDiameter : LengthValue;
    }
    
    part def SeparationVessel {
        port mixtureIn : MixtureTransferPort;
        port airOut : CompressedAirPort;
        port waterOut : WaterDischargePort;
        
        attribute vesselVolume : VolumeValue;
        attribute operatingPressure : AirPressureValue;
        attribute separationEfficiency : Real;
    }
    
    part def TailraceOutlet {
        port waterIn : WaterDischargePort;
        port waterOut : WaterDischargePort;
        
        attribute outletElevation : LengthValue;
    }
    
    action def EntrainAirIntoWater {
        in waterFlow : WaterFlowRateValue;
        in waterVelocity : SpeedValue;
        in ambientPressure : AirPressureValue;
        out airEntrainmentRate : AirFlowRateValue;
        out mixture : WaterAirMixture;
    }
    
    action def AccelerateDownShaft {
        in mixture : WaterAirMixture;
        in shaftDepth : ShaftDepthValue;
        in gravity : AccelerationValue;
        out acceleratedMixture : WaterAirMixture;
        out impactVelocity : SpeedValue;
    }
    
    action def CompressAirByHydrostaticPressure {
        in mixture : WaterAirMixture;
        in depth : ShaftDepthValue;
        in waterDensity : WaterDensityValue;
        out compressedAir : CompressedAir;
        out pressurizedWater : DischargedWater;
    }
    
    action def SeparateAirFromWater {
        in pressurizedMixture : WaterAirMixture;
        in vesselVolume : VolumeValue;
        out separatedAir : CompressedAir;
        out separatedWater : DischargedWater;
    }
    
    action def DischargeWaterToTailrace {
        in water : DischargedWater;
        in outletElevation : LengthValue;
        out discharged : DischargedWater;
    }
    
    action def OperateTrompeCompressor {
        in sourceWaterFlow : WaterFlowRateValue;
        in sourceWaterHead : WaterHeadValue;
        in operatingDepth : ShaftDepthValue;
        in atmosphericPressure : AirPressureValue;
        out compressedAirOutput : CompressedAir;
        out waterDischarge : DischargedWater;
        
        first start;
        then action entrainAir : EntrainAirIntoWater {
            in waterFlow = sourceWaterFlow;
            in waterVelocity;
            in ambientPressure = atmosphericPressure;
            out airEntrainmentRate;
            out mixture;
        }
        then action accelerate : AccelerateDownShaft {
            in mixture = entrainAir.mixture;
            in shaftDepth = operatingDepth;
            in gravity;
            out acceleratedMixture;
            out impactVelocity;
        }
        then action compress : CompressAirByHydrostaticPressure {
            in mixture = accelerate.acceleratedMixture;
            in depth = operatingDepth;
            in waterDensity;
            out compressedAir;
            out pressurizedWater;
        }
        then action separate : SeparateAirFromWater {
            in pressurizedMixture = accelerate.acceleratedMixture;
            in vesselVolume;
            out separatedAir;
            out separatedWater;
        }
        then action discharge : DischargeWaterToTailrace {
            in water = separate.separatedWater;
            in outletElevation;
            out discharged;
        }
        then assign compressedAirOutput := separate.separatedAir;
        then assign waterDischarge := discharge.discharged;
        then done;
    }
    
    part def Trompe {
        doc /* 
            A Trompe is a passive hydraulic air compressor that exploits the gravitational 
            potential energy of falling water to compress atmospheric air without any 
            mechanical moving parts. Water descends through a vertical shaft, entraining 
            air bubbles. As the water-air mixture falls, the increasing hydrostatic pressure 
            at depth compresses the entrained air. At the bottom, the compressed air is 
            separated from the water in a vessel and extracted for industrial use, while 
            the water is discharged through a tailrace.
        */
        
        attribute operatingShaftDepth : ShaftDepthValue;
        attribute designWaterFlowRate : WaterFlowRateValue;
        attribute targetAirPressure : AirPressureValue;
        attribute airOutputRate : AirFlowRateValue;
        
        port waterSupply : WaterSupplyPort;
        port airIntake : AirIntakePort;
        port compressedAirOutput : CompressedAirPort;
        port waterDischarge : WaterDischargePort;
        
        part intake : IntakeSection {
            port waterIn;
            port airIn;
            port mixtureOut;
        }
        
        part shaft : VerticalShaft {
            port mixtureIn;
            port mixtureOut;
            attribute shaftDepth = Trompe::operatingShaftDepth;
        }
        
        part separator : SeparationVessel {
            port mixtureIn;
            port airOut;
            port waterOut;
            attribute operatingPressure = Trompe::targetAirPressure;
        }
        
        part tailrace : TailraceOutlet {
            port waterIn;
            port waterOut;
        }
        
        connection intakeToShaft connect intake.mixtureOut to shaft.mixtureIn;
        connection shaftToSeparator connect shaft.mixtureOut to separator.mixtureIn;
        connection separatorToTailrace connect separator.waterOut to tailrace.waterIn;
        connection waterSupplyToIntake connect waterSupply to intake.waterIn;
        connection airIntakeToIntake connect airIntake to intake.airIn;
        connection separatorAirToOutput connect separator.airOut to compressedAirOutput;
        connection tailraceToDischarge connect tailrace.waterOut to waterDischarge;
        
        perform action operation : OperateTrompeCompressor {
            in sourceWaterFlow = Trompe::designWaterFlowRate;
            in sourceWaterHead;
            in operatingDepth = Trompe::operatingShaftDepth;
            in atmosphericPressure;
            out compressedAirOutput;
            out waterDischarge;
        }
    }
    
    requirement def TrompePrimaryFunctionRequirement {
        doc /* 
            The Trompe system shall compress atmospheric air using only the gravitational 
            potential energy of falling water, without requiring external power sources or 
            mechanical moving parts.
        */
        
        subject trompeSystem : Trompe;
        
        require constraint passiveOperation {
            doc /* The system shall operate passively without mechanical compressors or pumps. */
        }
        
        require constraint continuousAirCompression {
            doc /* The system shall continuously compress air as long as water supply is maintained. */
        }
        
        require constraint energyConversion {
            doc /* The system shall convert gravitational potential energy of water into compressed air. */
        }
    }
    
    requirement def TrompePerformanceRequirement {
        doc /* 
            The Trompe system shall deliver compressed air at specified pressure and flow rate 
            based on the available water head and flow.
        */
        
        subject trompeSystem : Trompe;
        
        require constraint minimumAirPressure {
            doc /* Output air pressure shall be at least 150 kPa absolute at design conditions. */
            trompeSystem.targetAirPressure >= 150000.0
        }
        
        require constraint airEntrainmentEfficiency {
            doc /* The system shall entrain air at 8% to 12% of water volume flow rate. */
        }
        
        require constraint separationEfficiency {
            doc /* Air-water separation efficiency shall exceed 95% at operating pressure. */
        }
    }
    
    requirement def TrompeReliabilityRequirement {
        doc /* 
            The Trompe system shall operate reliably with minimal maintenance due to 
            absence of moving parts.
        */
        
        subject trompeSystem : Trompe;
        
        require constraint noMovingParts {
            doc /* The compression mechanism shall contain no mechanical moving parts. */
        }
        
        require constraint corrosionResistance {
            doc /* All wetted surfaces shall resist corrosion from continuous water exposure. */
        }
    }
    
    part trompeInstance : Trompe {
        attribute operatingShaftDepth = 15.0[m];
        attribute designWaterFlowRate = 0.5[m^3/s];
        attribute targetAirPressure = 200000.0[Pa];
        attribute airOutputRate = 0.05[m^3/s];
        
        satisfy requirement trompePrimaryFunction : TrompePrimaryFunctionRequirement {
            subject trompeSystem = trompeInstance;
        }
        
        satisfy requirement trompePerformance : TrompePerformanceRequirement {
            subject trompeSystem = trompeInstance;
        }
        
        satisfy requirement trompeReliability : TrompeReliabilityRequirement {
            subject trompeSystem = trompeInstance;
        }
    }
}
