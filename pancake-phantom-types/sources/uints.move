module pancake_phantom_types::uints {

    use aptos_std::type_info::{type_of, struct_name};
    use aptos_framework::account;
    use aptos_framework::resource_account;
    use aptos_framework::code;
    use std::vector::{length, borrow};
    use std::signer;

    const DEFAULT_ADMIN: address = @default_admin;
    const RESOURCE_ACCOUNT: address = @pancake_phantom_types;
    const DEV: address = @dev;

    const ERROR_ONLY_ADMIN: u64 = 0;

    struct PhantomTypeMetadata has key {
        signer_cap: account::SignerCapability,
        admin: address,
    }

    fun init_module(sender: &signer) {
        let signer_cap = resource_account::retrieve_resource_account_cap(sender, DEV);
        let resource_signer = account::create_signer_with_capability(&signer_cap);
        move_to(&resource_signer, PhantomTypeMetadata {
            signer_cap,
            admin: DEFAULT_ADMIN,
        })
    }

    public fun get_number<UID>(): u64 {
        let struct_name = struct_name(&type_of<UID>());
        let len = length(&struct_name);
        let result: u64 = 0;
        let idx = 1; // Skip "U"
        while (idx < len) {
            result = 10 * result;
            let number = *borrow(&struct_name, idx) - 48;
            result = result + (number as u64);
            idx = idx + 1;
        };
        result
    }

    public entry fun set_admin(sender: &signer, new_admin: address) acquires PhantomTypeMetadata {
        let sender_addr = signer::address_of(sender);
        let metadata = borrow_global_mut<PhantomTypeMetadata>(RESOURCE_ACCOUNT);
        assert!(sender_addr == metadata.admin, ERROR_ONLY_ADMIN);
        metadata.admin = new_admin;
    }

    public entry fun upgrade_contract(sender: &signer, metadata_serialized: vector<u8>, code: vector<vector<u8>>) acquires PhantomTypeMetadata {
        let sender_addr = signer::address_of(sender);
        let metadata = borrow_global<PhantomTypeMetadata>(RESOURCE_ACCOUNT);
        assert!(sender_addr == metadata.admin, ERROR_ONLY_ADMIN);
        let resource_signer = account::create_signer_with_capability(&metadata.signer_cap);
        code::publish_package_txn(&resource_signer, metadata_serialized, code);
    }

    #[test]
    fun test_get_number() {
        let number = get_number<U0>();
        assert!(number == 0, 99);

        let number = get_number<U1>();
        assert!(number == 1, 98);

        let number = get_number<U10>();
        assert!(number == 10, 97);

        let number = get_number<U45>();
        assert!(number == 45, 96);

        let number = get_number<U99>();
        assert!(number == 99, 95);

        let number = get_number<U734>();
        assert!(number == 734, 94);

        let number = get_number<U1000>();
        assert!(number == 1000, 93);
    }


    struct U0 {}

    struct U1 {}

    struct U2 {}

    struct U3 {}

    struct U4 {}

    struct U5 {}

    struct U6 {}

    struct U7 {}

    struct U8 {}

    struct U9 {}

    struct U10 {}

    struct U11 {}

    struct U12 {}

    struct U13 {}

    struct U14 {}

    struct U15 {}

    struct U16 {}

    struct U17 {}

    struct U18 {}

    struct U19 {}

    struct U20 {}

    struct U21 {}

    struct U22 {}

    struct U23 {}

    struct U24 {}

    struct U25 {}

    struct U26 {}

    struct U27 {}

    struct U28 {}

    struct U29 {}

    struct U30 {}

    struct U31 {}

    struct U32 {}

    struct U33 {}

    struct U34 {}

    struct U35 {}

    struct U36 {}

    struct U37 {}

    struct U38 {}

    struct U39 {}

    struct U40 {}

    struct U41 {}

    struct U42 {}

    struct U43 {}

    struct U44 {}

    struct U45 {}

    struct U46 {}

    struct U47 {}

    struct U48 {}

    struct U49 {}

    struct U50 {}

    struct U51 {}

    struct U52 {}

    struct U53 {}

    struct U54 {}

    struct U55 {}

    struct U56 {}

    struct U57 {}

    struct U58 {}

    struct U59 {}

    struct U60 {}

    struct U61 {}

    struct U62 {}

    struct U63 {}

    struct U64 {}

    struct U65 {}

    struct U66 {}

    struct U67 {}

    struct U68 {}

    struct U69 {}

    struct U70 {}

    struct U71 {}

    struct U72 {}

    struct U73 {}

    struct U74 {}

    struct U75 {}

    struct U76 {}

    struct U77 {}

    struct U78 {}

    struct U79 {}

    struct U80 {}

    struct U81 {}

    struct U82 {}

    struct U83 {}

    struct U84 {}

    struct U85 {}

    struct U86 {}

    struct U87 {}

    struct U88 {}

    struct U89 {}

    struct U90 {}

    struct U91 {}

    struct U92 {}

    struct U93 {}

    struct U94 {}

    struct U95 {}

    struct U96 {}

    struct U97 {}

    struct U98 {}

    struct U99 {}

    struct U100 {}

    struct U101 {}

    struct U102 {}

    struct U103 {}

    struct U104 {}

    struct U105 {}

    struct U106 {}

    struct U107 {}

    struct U108 {}

    struct U109 {}

    struct U110 {}

    struct U111 {}

    struct U112 {}

    struct U113 {}

    struct U114 {}

    struct U115 {}

    struct U116 {}

    struct U117 {}

    struct U118 {}

    struct U119 {}

    struct U120 {}

    struct U121 {}

    struct U122 {}

    struct U123 {}

    struct U124 {}

    struct U125 {}

    struct U126 {}

    struct U127 {}

    struct U128 {}

    struct U129 {}

    struct U130 {}

    struct U131 {}

    struct U132 {}

    struct U133 {}

    struct U134 {}

    struct U135 {}

    struct U136 {}

    struct U137 {}

    struct U138 {}

    struct U139 {}

    struct U140 {}

    struct U141 {}

    struct U142 {}

    struct U143 {}

    struct U144 {}

    struct U145 {}

    struct U146 {}

    struct U147 {}

    struct U148 {}

    struct U149 {}

    struct U150 {}

    struct U151 {}

    struct U152 {}

    struct U153 {}

    struct U154 {}

    struct U155 {}

    struct U156 {}

    struct U157 {}

    struct U158 {}

    struct U159 {}

    struct U160 {}

    struct U161 {}

    struct U162 {}

    struct U163 {}

    struct U164 {}

    struct U165 {}

    struct U166 {}

    struct U167 {}

    struct U168 {}

    struct U169 {}

    struct U170 {}

    struct U171 {}

    struct U172 {}

    struct U173 {}

    struct U174 {}

    struct U175 {}

    struct U176 {}

    struct U177 {}

    struct U178 {}

    struct U179 {}

    struct U180 {}

    struct U181 {}

    struct U182 {}

    struct U183 {}

    struct U184 {}

    struct U185 {}

    struct U186 {}

    struct U187 {}

    struct U188 {}

    struct U189 {}

    struct U190 {}

    struct U191 {}

    struct U192 {}

    struct U193 {}

    struct U194 {}

    struct U195 {}

    struct U196 {}

    struct U197 {}

    struct U198 {}

    struct U199 {}

    struct U200 {}

    struct U201 {}

    struct U202 {}

    struct U203 {}

    struct U204 {}

    struct U205 {}

    struct U206 {}

    struct U207 {}

    struct U208 {}

    struct U209 {}

    struct U210 {}

    struct U211 {}

    struct U212 {}

    struct U213 {}

    struct U214 {}

    struct U215 {}

    struct U216 {}

    struct U217 {}

    struct U218 {}

    struct U219 {}

    struct U220 {}

    struct U221 {}

    struct U222 {}

    struct U223 {}

    struct U224 {}

    struct U225 {}

    struct U226 {}

    struct U227 {}

    struct U228 {}

    struct U229 {}

    struct U230 {}

    struct U231 {}

    struct U232 {}

    struct U233 {}

    struct U234 {}

    struct U235 {}

    struct U236 {}

    struct U237 {}

    struct U238 {}

    struct U239 {}

    struct U240 {}

    struct U241 {}

    struct U242 {}

    struct U243 {}

    struct U244 {}

    struct U245 {}

    struct U246 {}

    struct U247 {}

    struct U248 {}

    struct U249 {}

    struct U250 {}

    struct U251 {}

    struct U252 {}

    struct U253 {}

    struct U254 {}

    struct U255 {}

    struct U256 {}

    struct U257 {}

    struct U258 {}

    struct U259 {}

    struct U260 {}

    struct U261 {}

    struct U262 {}

    struct U263 {}

    struct U264 {}

    struct U265 {}

    struct U266 {}

    struct U267 {}

    struct U268 {}

    struct U269 {}

    struct U270 {}

    struct U271 {}

    struct U272 {}

    struct U273 {}

    struct U274 {}

    struct U275 {}

    struct U276 {}

    struct U277 {}

    struct U278 {}

    struct U279 {}

    struct U280 {}

    struct U281 {}

    struct U282 {}

    struct U283 {}

    struct U284 {}

    struct U285 {}

    struct U286 {}

    struct U287 {}

    struct U288 {}

    struct U289 {}

    struct U290 {}

    struct U291 {}

    struct U292 {}

    struct U293 {}

    struct U294 {}

    struct U295 {}

    struct U296 {}

    struct U297 {}

    struct U298 {}

    struct U299 {}

    struct U300 {}

    struct U301 {}

    struct U302 {}

    struct U303 {}

    struct U304 {}

    struct U305 {}

    struct U306 {}

    struct U307 {}

    struct U308 {}

    struct U309 {}

    struct U310 {}

    struct U311 {}

    struct U312 {}

    struct U313 {}

    struct U314 {}

    struct U315 {}

    struct U316 {}

    struct U317 {}

    struct U318 {}

    struct U319 {}

    struct U320 {}

    struct U321 {}

    struct U322 {}

    struct U323 {}

    struct U324 {}

    struct U325 {}

    struct U326 {}

    struct U327 {}

    struct U328 {}

    struct U329 {}

    struct U330 {}

    struct U331 {}

    struct U332 {}

    struct U333 {}

    struct U334 {}

    struct U335 {}

    struct U336 {}

    struct U337 {}

    struct U338 {}

    struct U339 {}

    struct U340 {}

    struct U341 {}

    struct U342 {}

    struct U343 {}

    struct U344 {}

    struct U345 {}

    struct U346 {}

    struct U347 {}

    struct U348 {}

    struct U349 {}

    struct U350 {}

    struct U351 {}

    struct U352 {}

    struct U353 {}

    struct U354 {}

    struct U355 {}

    struct U356 {}

    struct U357 {}

    struct U358 {}

    struct U359 {}

    struct U360 {}

    struct U361 {}

    struct U362 {}

    struct U363 {}

    struct U364 {}

    struct U365 {}

    struct U366 {}

    struct U367 {}

    struct U368 {}

    struct U369 {}

    struct U370 {}

    struct U371 {}

    struct U372 {}

    struct U373 {}

    struct U374 {}

    struct U375 {}

    struct U376 {}

    struct U377 {}

    struct U378 {}

    struct U379 {}

    struct U380 {}

    struct U381 {}

    struct U382 {}

    struct U383 {}

    struct U384 {}

    struct U385 {}

    struct U386 {}

    struct U387 {}

    struct U388 {}

    struct U389 {}

    struct U390 {}

    struct U391 {}

    struct U392 {}

    struct U393 {}

    struct U394 {}

    struct U395 {}

    struct U396 {}

    struct U397 {}

    struct U398 {}

    struct U399 {}

    struct U400 {}

    struct U401 {}

    struct U402 {}

    struct U403 {}

    struct U404 {}

    struct U405 {}

    struct U406 {}

    struct U407 {}

    struct U408 {}

    struct U409 {}

    struct U410 {}

    struct U411 {}

    struct U412 {}

    struct U413 {}

    struct U414 {}

    struct U415 {}

    struct U416 {}

    struct U417 {}

    struct U418 {}

    struct U419 {}

    struct U420 {}

    struct U421 {}

    struct U422 {}

    struct U423 {}

    struct U424 {}

    struct U425 {}

    struct U426 {}

    struct U427 {}

    struct U428 {}

    struct U429 {}

    struct U430 {}

    struct U431 {}

    struct U432 {}

    struct U433 {}

    struct U434 {}

    struct U435 {}

    struct U436 {}

    struct U437 {}

    struct U438 {}

    struct U439 {}

    struct U440 {}

    struct U441 {}

    struct U442 {}

    struct U443 {}

    struct U444 {}

    struct U445 {}

    struct U446 {}

    struct U447 {}

    struct U448 {}

    struct U449 {}

    struct U450 {}

    struct U451 {}

    struct U452 {}

    struct U453 {}

    struct U454 {}

    struct U455 {}

    struct U456 {}

    struct U457 {}

    struct U458 {}

    struct U459 {}

    struct U460 {}

    struct U461 {}

    struct U462 {}

    struct U463 {}

    struct U464 {}

    struct U465 {}

    struct U466 {}

    struct U467 {}

    struct U468 {}

    struct U469 {}

    struct U470 {}

    struct U471 {}

    struct U472 {}

    struct U473 {}

    struct U474 {}

    struct U475 {}

    struct U476 {}

    struct U477 {}

    struct U478 {}

    struct U479 {}

    struct U480 {}

    struct U481 {}

    struct U482 {}

    struct U483 {}

    struct U484 {}

    struct U485 {}

    struct U486 {}

    struct U487 {}

    struct U488 {}

    struct U489 {}

    struct U490 {}

    struct U491 {}

    struct U492 {}

    struct U493 {}

    struct U494 {}

    struct U495 {}

    struct U496 {}

    struct U497 {}

    struct U498 {}

    struct U499 {}

    struct U500 {}

    struct U501 {}

    struct U502 {}

    struct U503 {}

    struct U504 {}

    struct U505 {}

    struct U506 {}

    struct U507 {}

    struct U508 {}

    struct U509 {}

    struct U510 {}

    struct U511 {}

    struct U512 {}

    struct U513 {}

    struct U514 {}

    struct U515 {}

    struct U516 {}

    struct U517 {}

    struct U518 {}

    struct U519 {}

    struct U520 {}

    struct U521 {}

    struct U522 {}

    struct U523 {}

    struct U524 {}

    struct U525 {}

    struct U526 {}

    struct U527 {}

    struct U528 {}

    struct U529 {}

    struct U530 {}

    struct U531 {}

    struct U532 {}

    struct U533 {}

    struct U534 {}

    struct U535 {}

    struct U536 {}

    struct U537 {}

    struct U538 {}

    struct U539 {}

    struct U540 {}

    struct U541 {}

    struct U542 {}

    struct U543 {}

    struct U544 {}

    struct U545 {}

    struct U546 {}

    struct U547 {}

    struct U548 {}

    struct U549 {}

    struct U550 {}

    struct U551 {}

    struct U552 {}

    struct U553 {}

    struct U554 {}

    struct U555 {}

    struct U556 {}

    struct U557 {}

    struct U558 {}

    struct U559 {}

    struct U560 {}

    struct U561 {}

    struct U562 {}

    struct U563 {}

    struct U564 {}

    struct U565 {}

    struct U566 {}

    struct U567 {}

    struct U568 {}

    struct U569 {}

    struct U570 {}

    struct U571 {}

    struct U572 {}

    struct U573 {}

    struct U574 {}

    struct U575 {}

    struct U576 {}

    struct U577 {}

    struct U578 {}

    struct U579 {}

    struct U580 {}

    struct U581 {}

    struct U582 {}

    struct U583 {}

    struct U584 {}

    struct U585 {}

    struct U586 {}

    struct U587 {}

    struct U588 {}

    struct U589 {}

    struct U590 {}

    struct U591 {}

    struct U592 {}

    struct U593 {}

    struct U594 {}

    struct U595 {}

    struct U596 {}

    struct U597 {}

    struct U598 {}

    struct U599 {}

    struct U600 {}

    struct U601 {}

    struct U602 {}

    struct U603 {}

    struct U604 {}

    struct U605 {}

    struct U606 {}

    struct U607 {}

    struct U608 {}

    struct U609 {}

    struct U610 {}

    struct U611 {}

    struct U612 {}

    struct U613 {}

    struct U614 {}

    struct U615 {}

    struct U616 {}

    struct U617 {}

    struct U618 {}

    struct U619 {}

    struct U620 {}

    struct U621 {}

    struct U622 {}

    struct U623 {}

    struct U624 {}

    struct U625 {}

    struct U626 {}

    struct U627 {}

    struct U628 {}

    struct U629 {}

    struct U630 {}

    struct U631 {}

    struct U632 {}

    struct U633 {}

    struct U634 {}

    struct U635 {}

    struct U636 {}

    struct U637 {}

    struct U638 {}

    struct U639 {}

    struct U640 {}

    struct U641 {}

    struct U642 {}

    struct U643 {}

    struct U644 {}

    struct U645 {}

    struct U646 {}

    struct U647 {}

    struct U648 {}

    struct U649 {}

    struct U650 {}

    struct U651 {}

    struct U652 {}

    struct U653 {}

    struct U654 {}

    struct U655 {}

    struct U656 {}

    struct U657 {}

    struct U658 {}

    struct U659 {}

    struct U660 {}

    struct U661 {}

    struct U662 {}

    struct U663 {}

    struct U664 {}

    struct U665 {}

    struct U666 {}

    struct U667 {}

    struct U668 {}

    struct U669 {}

    struct U670 {}

    struct U671 {}

    struct U672 {}

    struct U673 {}

    struct U674 {}

    struct U675 {}

    struct U676 {}

    struct U677 {}

    struct U678 {}

    struct U679 {}

    struct U680 {}

    struct U681 {}

    struct U682 {}

    struct U683 {}

    struct U684 {}

    struct U685 {}

    struct U686 {}

    struct U687 {}

    struct U688 {}

    struct U689 {}

    struct U690 {}

    struct U691 {}

    struct U692 {}

    struct U693 {}

    struct U694 {}

    struct U695 {}

    struct U696 {}

    struct U697 {}

    struct U698 {}

    struct U699 {}

    struct U700 {}

    struct U701 {}

    struct U702 {}

    struct U703 {}

    struct U704 {}

    struct U705 {}

    struct U706 {}

    struct U707 {}

    struct U708 {}

    struct U709 {}

    struct U710 {}

    struct U711 {}

    struct U712 {}

    struct U713 {}

    struct U714 {}

    struct U715 {}

    struct U716 {}

    struct U717 {}

    struct U718 {}

    struct U719 {}

    struct U720 {}

    struct U721 {}

    struct U722 {}

    struct U723 {}

    struct U724 {}

    struct U725 {}

    struct U726 {}

    struct U727 {}

    struct U728 {}

    struct U729 {}

    struct U730 {}

    struct U731 {}

    struct U732 {}

    struct U733 {}

    struct U734 {}

    struct U735 {}

    struct U736 {}

    struct U737 {}

    struct U738 {}

    struct U739 {}

    struct U740 {}

    struct U741 {}

    struct U742 {}

    struct U743 {}

    struct U744 {}

    struct U745 {}

    struct U746 {}

    struct U747 {}

    struct U748 {}

    struct U749 {}

    struct U750 {}

    struct U751 {}

    struct U752 {}

    struct U753 {}

    struct U754 {}

    struct U755 {}

    struct U756 {}

    struct U757 {}

    struct U758 {}

    struct U759 {}

    struct U760 {}

    struct U761 {}

    struct U762 {}

    struct U763 {}

    struct U764 {}

    struct U765 {}

    struct U766 {}

    struct U767 {}

    struct U768 {}

    struct U769 {}

    struct U770 {}

    struct U771 {}

    struct U772 {}

    struct U773 {}

    struct U774 {}

    struct U775 {}

    struct U776 {}

    struct U777 {}

    struct U778 {}

    struct U779 {}

    struct U780 {}

    struct U781 {}

    struct U782 {}

    struct U783 {}

    struct U784 {}

    struct U785 {}

    struct U786 {}

    struct U787 {}

    struct U788 {}

    struct U789 {}

    struct U790 {}

    struct U791 {}

    struct U792 {}

    struct U793 {}

    struct U794 {}

    struct U795 {}

    struct U796 {}

    struct U797 {}

    struct U798 {}

    struct U799 {}

    struct U800 {}

    struct U801 {}

    struct U802 {}

    struct U803 {}

    struct U804 {}

    struct U805 {}

    struct U806 {}

    struct U807 {}

    struct U808 {}

    struct U809 {}

    struct U810 {}

    struct U811 {}

    struct U812 {}

    struct U813 {}

    struct U814 {}

    struct U815 {}

    struct U816 {}

    struct U817 {}

    struct U818 {}

    struct U819 {}

    struct U820 {}

    struct U821 {}

    struct U822 {}

    struct U823 {}

    struct U824 {}

    struct U825 {}

    struct U826 {}

    struct U827 {}

    struct U828 {}

    struct U829 {}

    struct U830 {}

    struct U831 {}

    struct U832 {}

    struct U833 {}

    struct U834 {}

    struct U835 {}

    struct U836 {}

    struct U837 {}

    struct U838 {}

    struct U839 {}

    struct U840 {}

    struct U841 {}

    struct U842 {}

    struct U843 {}

    struct U844 {}

    struct U845 {}

    struct U846 {}

    struct U847 {}

    struct U848 {}

    struct U849 {}

    struct U850 {}

    struct U851 {}

    struct U852 {}

    struct U853 {}

    struct U854 {}

    struct U855 {}

    struct U856 {}

    struct U857 {}

    struct U858 {}

    struct U859 {}

    struct U860 {}

    struct U861 {}

    struct U862 {}

    struct U863 {}

    struct U864 {}

    struct U865 {}

    struct U866 {}

    struct U867 {}

    struct U868 {}

    struct U869 {}

    struct U870 {}

    struct U871 {}

    struct U872 {}

    struct U873 {}

    struct U874 {}

    struct U875 {}

    struct U876 {}

    struct U877 {}

    struct U878 {}

    struct U879 {}

    struct U880 {}

    struct U881 {}

    struct U882 {}

    struct U883 {}

    struct U884 {}

    struct U885 {}

    struct U886 {}

    struct U887 {}

    struct U888 {}

    struct U889 {}

    struct U890 {}

    struct U891 {}

    struct U892 {}

    struct U893 {}

    struct U894 {}

    struct U895 {}

    struct U896 {}

    struct U897 {}

    struct U898 {}

    struct U899 {}

    struct U900 {}

    struct U901 {}

    struct U902 {}

    struct U903 {}

    struct U904 {}

    struct U905 {}

    struct U906 {}

    struct U907 {}

    struct U908 {}

    struct U909 {}

    struct U910 {}

    struct U911 {}

    struct U912 {}

    struct U913 {}

    struct U914 {}

    struct U915 {}

    struct U916 {}

    struct U917 {}

    struct U918 {}

    struct U919 {}

    struct U920 {}

    struct U921 {}

    struct U922 {}

    struct U923 {}

    struct U924 {}

    struct U925 {}

    struct U926 {}

    struct U927 {}

    struct U928 {}

    struct U929 {}

    struct U930 {}

    struct U931 {}

    struct U932 {}

    struct U933 {}

    struct U934 {}

    struct U935 {}

    struct U936 {}

    struct U937 {}

    struct U938 {}

    struct U939 {}

    struct U940 {}

    struct U941 {}

    struct U942 {}

    struct U943 {}

    struct U944 {}

    struct U945 {}

    struct U946 {}

    struct U947 {}

    struct U948 {}

    struct U949 {}

    struct U950 {}

    struct U951 {}

    struct U952 {}

    struct U953 {}

    struct U954 {}

    struct U955 {}

    struct U956 {}

    struct U957 {}

    struct U958 {}

    struct U959 {}

    struct U960 {}

    struct U961 {}

    struct U962 {}

    struct U963 {}

    struct U964 {}

    struct U965 {}

    struct U966 {}

    struct U967 {}

    struct U968 {}

    struct U969 {}

    struct U970 {}

    struct U971 {}

    struct U972 {}

    struct U973 {}

    struct U974 {}

    struct U975 {}

    struct U976 {}

    struct U977 {}

    struct U978 {}

    struct U979 {}

    struct U980 {}

    struct U981 {}

    struct U982 {}

    struct U983 {}

    struct U984 {}

    struct U985 {}

    struct U986 {}

    struct U987 {}

    struct U988 {}

    struct U989 {}

    struct U990 {}

    struct U991 {}

    struct U992 {}

    struct U993 {}

    struct U994 {}

    struct U995 {}

    struct U996 {}

    struct U997 {}

    struct U998 {}

    struct U999 {}

    struct U1000 {}
}