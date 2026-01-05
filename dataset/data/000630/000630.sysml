package HotWaterBottleSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureRange {
		attribute minTemp : TemperatureValue;
		attribute maxTemp : TemperatureValue;
	}
	
	item def HotWater {
		attribute temperature : TemperatureValue;
		attribute volume : VolumeValue;
	}
	
	item def ThermalEnergy {
		attribute power : PowerValue;
	}
	
	part def RubberContainer {
		attribute capacity : VolumeValue;
		attribute wallThickness : LengthValue;
		attribute thermalConductivity : Real;
		attribute operatingTempRange : TemperatureRange;
		port fillOpening;
		port externalSurface;
	}
	
	part def ScrewCap {
		attribute diameter : LengthValue;
		attribute sealIntegrity : Real;
		port capInterface;
	}
	
	part def FabricCover {
		attribute material : String;
		attribute thermalInsulation : Real;
		port coverSurface;
	}
	
	action def FillBottle {
		in waterSupply : HotWater;
		in containerCapacity : VolumeValue;
		out filledVolume : VolumeValue;
		out waterTemperature : TemperatureValue;
		
		first start;
		then decide;
			if waterSupply.volume <= containerCapacity then acceptFill;
			else rejectFill;
		action acceptFill {
			then assign filledVolume := waterSupply.volume;
			then assign waterTemperature := waterSupply.temperature;
		}
		action rejectFill {
			then assign filledVolume := 0.0 [SI::L];
			then assign waterTemperature := 293.15 [SI::K];
		}
		then done;
	}
	
	action def SealBottle {
		in capIntegrity : Real;
		out isSealed : Boolean;
		
		first start;
		then decide;
			if capIntegrity >= 0.95 then sealedAction;
			else unsealedAction;
		action sealedAction {
			then assign isSealed := true;
		}
		action unsealedAction {
			then assign isSealed := false;
		}
		then done;
	}
	
	action def TransferHeat {
		in currentTemp : TemperatureValue;
		in ambientTemp : TemperatureValue;
		in thermalResistance : Real;
		in timeStep : TimeValue;
		out newTemp : TemperatureValue;
		out heatLoss : PowerValue;
		
		first start;
		then assign heatLoss := (currentTemp - ambientTemp) / thermalResistance;
		then assign newTemp := currentTemp - (heatLoss * timeStep / 8000.0);
		then done;
	}
	
	state def BottleOperationalStates {
		entry; then empty;
		
		state empty {
			entry assign bottleTemp := ambientTemp;
		}
		then filled via FillEvent;
		
		state filled;
		then sealed via SealEvent;
		
		state sealed;
		then active via ApplyEvent;
		
		state active {
			do action radiateHeat : TransferHeat {
				in currentTemp = bottleTemp;
				in ambientTemp = environmentTemp;
				in thermalResistance = totalThermalResistance;
				in timeStep = 600.0 [SI::s];
				out newTemp;
				out heatLoss;
			}
		}
		then cooling via RemoveEvent;
		
		state cooling {
			do action coolDown : TransferHeat {
				in currentTemp = bottleTemp;
				in ambientTemp = environmentTemp;
				in thermalResistance = totalThermalResistance;
				in timeStep = 300.0 [SI::s];
				out newTemp;
				out heatLoss;
			}
		}
		then empty via EmptyEvent;
		
		attribute bottleTemp : TemperatureValue;
		attribute ambientTemp : TemperatureValue;
		attribute environmentTemp : TemperatureValue;
		attribute totalThermalResistance : Real;
	}
	
	event def FillEvent;
	event def SealEvent;
	event def ApplyEvent;
	event def RemoveEvent;
	event def EmptyEvent;
	
	requirement def SafetyRequirement {
		doc /* The hot water bottle shall safely contain hot water without risk of burns or leakage. */
		
		require constraint maxTemperatureConstraint {
			doc /* Maximum water temperature shall not exceed 353.15 K to prevent burns. */
		}
		
		require constraint sealIntegrityConstraint {
			doc /* Seal integrity shall be maintained above 95% to prevent leakage. */
		}
		
		require constraint materialStrengthConstraint {
			doc /* Container material shall withstand operating temperature range without degradation. */
		}
	}
	
	requirement def PerformanceRequirement {
		doc /* The hot water bottle shall maintain therapeutic warmth for extended duration. */
		
		require constraint heatRetentionConstraint {
			doc /* Bottle shall maintain temperature above 313.15 K for minimum 2 hours. */
		}
		
		require constraint comfortableTemperatureConstraint {
			doc /* External surface temperature shall remain comfortable for direct skin contact. */
		}
	}
	
	requirement def UsabilityRequirement {
		doc /* The hot water bottle shall be easy and safe to fill, seal, and use. */
		
		require constraint fillEaseConstraint {
			doc /* Fill opening shall accommodate standard pouring without spillage. */
		}
		
		require constraint sealOperationConstraint {
			doc /* Screw cap shall provide secure closure with simple manual operation. */
		}
	}
	
	part def HotWaterBottle {
		attribute maxCapacity : VolumeValue;
		attribute maxSafeTemp : TemperatureValue;
		attribute minTherapeuticTemp : TemperatureValue;
		attribute minRetentionDuration : TimeValue;
		
		part container : RubberContainer {
			attribute :>> capacity = maxCapacity;
			attribute :>> wallThickness = 3.0 [SI::mm];
			attribute :>> thermalConductivity = 0.18;
			attribute :>> operatingTempRange {
				attribute :>> minTemp = 273.15 [SI::K];
				attribute :>> maxTemp = maxSafeTemp;
			}
		}
		
		part cap : ScrewCap {
			attribute :>> diameter = 45.0 [SI::mm];
			attribute :>> sealIntegrity = 0.98;
		}
		
		part cover : FabricCover {
			attribute :>> material = "cotton fleece";
			attribute :>> thermalInsulation = 0.65;
		}
		
		port waterInlet;
		port heatOutput;
		
		connection capConnection connect cap.capInterface to container.fillOpening;
		connection coverConnection connect cover.coverSurface to container.externalSurface;
		
		perform action operationSequence : OperateBottle;
		perform state lifecycle : BottleOperationalStates;
	}
	
	action def OperateBottle {
		in fillTemp : TemperatureValue;
		in fillVolume : VolumeValue;
		in ambientTemp : TemperatureValue;
		in usageDuration : TimeValue;
		out finalTemp : TemperatureValue;
		out totalHeatDelivered : EnergyValue;
		
		private attribute currentTemp : TemperatureValue;
		private attribute sealed : Boolean;
		
		first start;
		
		then action fillAction : FillBottle {
			in waterSupply : HotWater {
				attribute :>> temperature = fillTemp;
				attribute :>> volume = fillVolume;
			}
			in containerCapacity = 2.0 [SI::L];
			out filledVolume;
			out waterTemperature;
		}
		
		then action sealAction : SealBottle {
			in capIntegrity = 0.98;
			out isSealed;
		}
		
		then assign currentTemp := fillAction.waterTemperature;
		then assign sealed := sealAction.isSealed;
		
		then action deliverHeat {
			private attribute elapsedTime : TimeValue := 0.0 [SI::s];
			private attribute temp : TemperatureValue := currentTemp;
			
			while elapsedTime < usageDuration and temp > 313.15 [SI::K] {
				perform action heatStep : TransferHeat {
					in currentTemp = temp;
					in ambientTemp = ambientTemp;
					in thermalResistance = 0.4;
					in timeStep = 600.0 [SI::s];
					out newTemp;
					out heatLoss;
				}
				then assign temp := heatStep.newTemp;
				then assign elapsedTime := elapsedTime + 600.0 [SI::s];
			}
			then assign finalTemp := temp;
		}
		
		then done;
	}
	
	part bottleSystem : HotWaterBottle {
		attribute :>> maxCapacity = 2.0 [SI::L];
		attribute :>> maxSafeTemp = 353.15 [SI::K];
		attribute :>> minTherapeuticTemp = 313.15 [SI::K];
		attribute :>> minRetentionDuration = 7200.0 [SI::s];
		
		perform action usage : OperateBottle {
			in fillTemp = 348.15 [SI::K];
			in fillVolume = 1.8 [SI::L];
			in ambientTemp = 295.15 [SI::K];
			in usageDuration = 10800.0 [SI::s];
			out finalTemp;
			out totalHeatDelivered;
		}
	}
	
	requirement systemPrimaryFunction {
		doc /* The hot water bottle system shall provide sustained, safe therapeutic warmth 
		       by containing hot water and gradually releasing thermal energy to the user 
		       for pain relief, comfort, and relaxation over an extended period. */
		
		assume constraint hotWaterAvailable {
			doc /* Hot water at safe temperature between 343.15-353.15 K is available for filling. */
		}
		
		require safetyReq : SafetyRequirement;
		require performanceReq : PerformanceRequirement;
		require usabilityReq : UsabilityRequirement;
		
		satisfy by bottleSystem;
	}
}
