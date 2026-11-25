package main

import (
	"encoding/json"
	"errors"
	"strings"
)

// The entity registry's display format is a compact, stable Home Assistant
// websocket interface. Device and area metadata is resolved on the server so
// the browser receives only information associated with readable entities.
type haDisplayEntry struct {
	EntityID string `json:"ei"`
	AreaID   string `json:"ai"`
	DeviceID string `json:"di"`
	Hidden   bool   `json:"hb"`
	Name     string `json:"en"`
}

type haDisplayRegistry struct {
	Entities []haDisplayEntry `json:"entities"`
}

type haDeviceEntry struct {
	ID             string `json:"id"`
	AreaID         string `json:"area_id"`
	ParentDeviceID string `json:"parent_device_id"`
	Name           string `json:"name"`
	NameByUser     string `json:"name_by_user"`
	Model          string `json:"model"`
}

type haAreaEntry struct {
	AreaID string `json:"area_id"`
	Name   string `json:"name"`
	Icon   string `json:"icon"`
}

type haRegistryData struct {
	Entities haDisplayRegistry
	Devices  []haDeviceEntry
	Areas    []haAreaEntry
}

type homeDeviceMetadata struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Model string `json:"model"`
	Room  string `json:"room"`
}

type homeRegistryMetadata struct {
	Areas     map[string]string             `json:"areas"`
	Devices   map[string]homeDeviceMetadata `json:"devices"`
	RoomIcons map[string]string             `json:"roomIcons"`
}

func decodeHomeRegistry(kind string, data json.RawMessage, registry *haRegistryData) error {
	switch kind {
	case "entities":
		return json.Unmarshal(data, &registry.Entities)
	case "devices":
		return json.Unmarshal(data, &registry.Devices)
	case "areas":
		return json.Unmarshal(data, &registry.Areas)
	default:
		return errors.New("unexpected Home Assistant registry")
	}
}

func validRegistryLabel(value string, max int) string {
	value = strings.TrimSpace(value)
	if len(value) > max {
		return ""
	}
	return value
}

func buildHomeRegistryMetadata(states map[string]homeEntity, registry haRegistryData) homeRegistryMetadata {
	result := homeRegistryMetadata{
		Areas: map[string]string{}, Devices: map[string]homeDeviceMetadata{}, RoomIcons: map[string]string{},
	}
	areas := map[string]haAreaEntry{}
	devices := map[string]haDeviceEntry{}
	for _, entry := range registry.Areas {
		if entry.AreaID != "" {
			areas[entry.AreaID] = entry
		}
	}
	for _, entry := range registry.Devices {
		if entry.ID != "" {
			devices[entry.ID] = entry
		}
	}
	for _, entity := range registry.Entities.Entities {
		state, allowed := states[entity.EntityID]
		if !allowed || !entityPattern.MatchString(entity.EntityID) || entity.Hidden {
			continue
		}
		var device haDeviceEntry
		if entity.DeviceID != "" {
			device = devices[entity.DeviceID]
		}
		areaID := entity.AreaID
		if areaID == "" {
			areaID = device.AreaID
		}
		// Child devices may inherit the area of a parent device.
		parentID := device.ParentDeviceID
		for depth := 0; depth < 8 && areaID == "" && parentID != ""; depth++ {
			parent, exists := devices[parentID]
			if !exists || parent.ID == device.ID {
				break
			}
			areaID = parent.AreaID
			parentID = parent.ParentDeviceID
		}
		area := areas[areaID]
		room := validRegistryLabel(area.Name, 80)
		if room != "" {
			result.Areas[entity.EntityID] = room
			icon := validRegistryLabel(area.Icon, 80)
			if strings.HasPrefix(icon, "mdi:") && len(icon) > 4 {
				result.RoomIcons[room] = icon
			}
		}
		if entity.DeviceID == "" || device.ID == "" || len(device.ID) > 128 {
			continue
		}
		name := validRegistryLabel(device.NameByUser, 128)
		if name == "" {
			name = validRegistryLabel(device.Name, 128)
		}
		if name == "" {
			name = validRegistryLabel(entity.Name, 128)
		}
		if name == "" {
			if friendlyName, ok := state.Attributes["friendly_name"].(string); ok {
				name = validRegistryLabel(friendlyName, 128)
			}
		}
		result.Devices[entity.EntityID] = homeDeviceMetadata{
			ID: device.ID, Name: name, Room: room, Model: validRegistryLabel(device.Model, 128),
		}
	}
	return result
}
