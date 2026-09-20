@tool
class_name BayterekLayer
extends Resource
## Tüm katmanların türediği base sınıf.
##
## Her katman bağımsız bir transform'a ve kendi state→görsel eşlemesine sahiptir.
## Katmanlar node seviyesinde bir kere hesaplanan aktif state listesini alır
## ve kendi checkbox'larına göre hangi state'in geçerli olduğuna karar verir.

## Node'da bulunabilecek tüm state isimleri.
## Sıralama ÖNCELİK DEĞİL — sadece listeleme ve UI iterasyonu için.
const STATES: Array[String] = [
	"normal",
	"hover",
	"clicked",
	"locked",
	"preallocated",
	"prerefund",
	"max_level",
	"allocateable",
	"not_allocateable",
]

## State çözümleme önceliği — aktif state'ler arasından katmanın hangisini
## seçeceğini belirler. Index 0 = en yüksek öncelik.
##
## Örnek: Node aynı anda hem "clicked" hem "hover" ise → katmanın her ikisinin
## de checkbox'ı ON ise "clicked" seçilir (önce gelir).
## Katmanın clicked checkbox'ı OFF, hover ON ise → "hover" seçilir.
## Hiçbiri ON değilse → "normal" fallback.
const STATE_PRIORITY: Array[String] = [
	"clicked",
	"hover",
	"prerefund",
	"preallocated",
	"allocateable",
	"not_allocateable",
	"max_level",
	"locked",
	"normal",
]

## Katmanın görünen ismi (UI'da gösterilir, kullanıcı düzenleyebilir).
@export_storage var layer_name: String = "Layer"

## Katmanın görünür olup olmadığı. `false` ise `_draw()` atlanır.
@export_storage var visible: bool = true

## Katmanın transform verisi (position, size, rotation, skew, pivot).
@export_storage var transform: BayterekLayerTransform

# ============================================================
# ANİMASYON (Faz 5 için yer tutucu)
# ============================================================

## Animasyon sistemi Faz 5'te gelecek. Şimdilik sadece veri alanı.
## Boş string = animasyon yok.
@export_storage var animation_id: String = ""

## Hızlı kontrol: animasyon aktif mi?
@export_storage var animated: bool = false

# ============================================================
# INIT
# ============================================================

func _init() -> void:
	if not transform:
		transform = BayterekLayerTransform.new()

# ============================================================
# STATE ÇÖZÜMLEME
# ============================================================

## Node'un aktif state'lerini ve bu katmanın checkbox'larını birleştirip
## katmanın hangi state'i kullanacağını döndürür.
##
## `node_states` → {"hover": true, "locked": false, ...} formatında
##                 node seviyesinde bir kere hesaplanmış aktif state'ler.
##
## Dönüş: STATE_PRIORITY sırasına göre ilk uyan state ismi.
##        Hiçbiri uymazsa "normal".
func get_visual_state(node_states: Dictionary) -> String:
	for state in STATE_PRIORITY:
		if not _is_state_checkbox_on(state):
			continue
		if state == "normal":
			# normal her zaman "fallback" — öncelik listesinin sonunda,
			# checkbox'ı ON ise direkt döner.
			return "normal"
		if node_states.get(state, false):
			return state
	return "normal"

## Alt sınıflar override eder — katman tipine göre checkbox kaynağı değişir.
## Base'de her zaman `false` döner (base sınıfın kendi checkbox'ı yok).
func _is_state_checkbox_on(_state: String) -> bool:
	return false

# ============================================================
# BOYUT YARDIMCILARI
# ============================================================

## Katmanın efektif boyutunu döndürür (transform üzerinden).
## `design_size` fallback olarak kullanılır.
func get_size(design_size: Vector2) -> Vector2:
	if not transform:
		return design_size
	return transform.get_effective_size(design_size)

## Katmanın transform matrisini döndürür.
func get_matrix(design_size: Vector2) -> Transform2D:
	if not transform:
		return Transform2D.IDENTITY
	return transform.get_matrix(design_size)

# ============================================================
# DUPLICATE
# ============================================================

## Alt sınıflar override eder — base sadece ortak alanları kopyalar.
func duplicate_layer() -> BayterekLayer:
	var copy := BayterekLayer.new()
	_copy_base_to(copy)
	return copy

## Base alanları `target`'a kopyalar. Alt sınıflar `duplicate_layer()`
## içinde bunu çağırıp kendi alanlarını ekler.
func _copy_base_to(target: BayterekLayer) -> void:
	target.layer_name = layer_name
	target.visible = visible
	target.transform = transform.duplicate_transform() if transform else BayterekLayerTransform.new()
	target.animation_id = animation_id
	target.animated = animated

# ============================================================
# DEBUG
# ============================================================

func _to_string() -> String:
	return "%s(name='%s', visible=%s)" % [
		get_script().resource_path.get_file() if get_script() else "BayterekLayer",
		layer_name,
		visible,
	]