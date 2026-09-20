İç Dolgu (Fill):

Renk — palette'ten seçilir

Renk:

Palette'ten renk (tint için)

bunları yanlış anlamışsın state based coloring olacak demek istemiştim tabi hepsi için color picker açılır bir tane

kaplama tipineki katmanlarda ikonlarda state based olabilir
positon da ekleyebiliriz katmanlara

1. katman sayısı 6 tane max olsun
2. katman bazında sistemin gücü olayı bu olacak zaten
3. evet bu da state based olacak
4. bağımsız olur node editorde ayarlarız güzel görünecek şekilde node boyutunu bu node'u canvasta kullanırken scale olarak ayarlarız
5. 2d skew yapalım şimdilik bakalım diğer türlü çok uğraş olacak
6. tree sekmesinin yapısının çoğu kısmını kopyalarız zaten 
- unity prefab paneli gibi olacak aslında
- katman listesi + seçili katmanın detayları olur
7. kaldırılacak onlar. ayrı ikon ve border için ayrı bir kaplama (texture) katmanı oluşturup onları kullanıcaz çünkü
8. evet prefablarda aynı yapıda olacak
9. _draw yapalım
10. dursun ama şöyle
- seçimi oyun içinde state based ile yeni sistem halleder
- canvas içinde seçim çerçevesi durur state based sistem çalışır halde olmadığından
- crown zaten dursun şimdilik sonradan bir ayar çekmemiz gerekebilir ama
11. pivot katman merkezi olur ama pivot un yerini ayarlayabiliriz katman üzerindeki 9 noktayada koyabiliriz
12. katman based animasyon ekleyedebiliriz temelini atalım ama bir düşünelim bu sistemide ama en son ekleriz 

---------------------------------------------------------

7. Node Editor UI
Unity prefab paneli tarzında:

Sol: Katman listesi (ekle / sil / sırala / seç)

Sağ: Seçili katmanın detay paneli (transform, tip, state renkleri, opsiyoneller)

Üstte: node preview (gerçek zamanlı render)

Bayterek'teki mevcut PrefabsPanel yapısına benzer bir layout.

tree sekmesinin yapısının aynısı kullanılır ya sadece bir iki buton ekleyebiliriz

düzeltemeler
normal ile allocated aynı şey olur 

1. ilk locked gelir açınca (allocated) olur normal haline döner yani 
2. hover öncellikli ama mesela şöyle olur
- iki katman yaparız birisinin hover'ını ayarlarız diğerinin allocated'ını ayarlar hover'ı ayarlamayız
bu node açıldığında allocated halinide göstermiş oluruz başka bir katmandada hover efektini gösteririz
yani tek texture üzerinde her şeyi göstermemize gerek yok anladın
3. shape'in özelliği olur anlattığıın gibi kullanımı olur
4. shape katmanında olur sadece
5. evet bu şekil
6. evet her node'a özel vec2 scale alanı
7. önerin iyidir

yeni planı ver bunlara göre ver yine
